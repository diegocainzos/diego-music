import AVFoundation
import Combine
import Foundation
#if os(iOS)
import MediaPlayer
import UIKit
#endif

enum AudioPlaybackState: Equatable, Sendable {
    case idle
    case resolving
    case buffering
    case playing
    case paused
    case ended
    case failed
}

@MainActor
final class AudioPlayerCoordinator: ObservableObject {
    @Published private(set) var playbackState: AudioPlaybackState = .idle
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var repeatMode: RepeatMode = .off
    @Published private(set) var shuffleEnabled: Bool = false
    @Published var volume: Float = 1.0 {
        didSet {
            player.volume = max(0, min(volume, 1.0))
        }
    }

    private let player = AVPlayer()
    private let queue: PlaybackQueue
    let resolver: any AudioStreamResolving
    private let youtubeService: (any YouTubeDataServicing)?
    private let relatedProvider: (any RelatedTrackProviding)?
    /// Gestor de descargas offline: si existe URL local, la usa directamente.
    var offlineManager: OfflineDownloadManager?

    /// Acceso directo al resolver para uso externo (ej. DownloadAllButton en vistas).
    var resolverClient: (any AudioStreamResolving)? { resolver }
    private var resolveTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var queueObservation: AnyCancellable?
    private var loadGeneration = 0
    private var automaticRetryAvailable = true
    private var radioTask: Task<Void, Never>?
    private var pendingSeekSeconds: Double?
    private var lastPersistedPosition: Double = 0
    /// Callback para persistir la pista activa + posición ("continuar donde dejaste").
    var positionPersister: ((MediaItem, Double) -> Void)?
    private var periodicTimeObserver: Any?
    private var timeControlObservation: NSKeyValueObservation?
    private var itemStatusObservation: NSKeyValueObservation?
    private var notificationObservers: [NSObjectProtocol] = []
    #if os(iOS)
    private var remoteCommandTargets: [(MPRemoteCommand, Any)] = []
    private var artworkTask: Task<Void, Never>?
    private var artworkItemID: MediaItem.ID?
    #endif

    init(
        queue: PlaybackQueue,
        resolver: any AudioStreamResolving,
        youtubeService: (any YouTubeDataServicing)? = nil,
        relatedProvider: (any RelatedTrackProviding)? = nil
    ) {
        self.queue = queue
        self.resolver = resolver
        self.youtubeService = youtubeService
        self.relatedProvider = relatedProvider
        observePlayer()
        observeQueueForPrefetch()
        configurePlatformPlayback()
    }

    deinit {
        resolveTask?.cancel()
        recoveryTask?.cancel()
        prefetchTask?.cancel()
        radioTask?.cancel()
        queueObservation?.cancel()
        if let periodicTimeObserver {
            player.removeTimeObserver(periodicTimeObserver)
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        #if os(iOS)
        for (command, target) in remoteCommandTargets {
            command.removeTarget(target)
        }
        artworkTask?.cancel()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }

    var isPlaying: Bool { playbackState == .playing }
    var isLoading: Bool { playbackState == .resolving || playbackState == .buffering }
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func select(_ item: MediaItem) {
        queue.play(item)
        load(item, autoplay: true, resetRetryBudget: true)
        triggerSmartRadioQueue(for: item)
    }

    func triggerSmartRadioQueue(for item: MediaItem) {
        guard let service = youtubeService else { return }
        radioTask?.cancel()
        radioTask = Task { [weak self, queue] in
            do {
                let relatedRadioItems = try await service.fetchRelatedRadio(for: item)
                try Task.checkCancellation()
                await MainActor.run {
                    queue.enqueueBatch(relatedRadioItems)
                }
            } catch {
                // Radio best-effort
            }
        }
    }

    func togglePlayback() {
        if isPlaying {
            player.pause()
            playbackState = .paused
            persistPosition(throttled: false)
            updateNowPlayingInfo()
            return
        }

        if player.currentItem == nil {
            if let item = queue.current { load(item, autoplay: true, resetRetryBudget: true) }
            return
        }
        guard activatePlatformAudioSession() else { return }
        player.play()
        updateNowPlayingInfo()
    }

    func retry() {
        guard let item = queue.current else { return }
        load(item, autoplay: true, resetRetryBudget: true)
    }

    func next() {
        guard let item = queue.advance() else {
            // Fin de cola: repeat all reinicia; si no, radio best-effort.
            handleQueueEnded()
            return
        }
        load(item, autoplay: true, resetRetryBudget: true)
    }

    // MARK: - Modos de reproducción

    func toggleShuffle() {
        shuffleEnabled.toggle()
        queue.setShuffle(shuffleEnabled)
    }

    func cycleRepeat() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }

    /// Al terminar la pista actual, respeta repeat one/all y radio best-effort.
    private func handleEndOfPlayback() {
        switch repeatMode {
        case .one:
            if let item = queue.current {
                load(item, autoplay: true, resetRetryBudget: true)
            }
        case .all:
            if queue.canAdvance {
                next()
            } else if let first = queue.resetToStart() {
                load(first, autoplay: true, resetRetryBudget: true)
            }
        case .off:
            next()
        }
    }

    /// Autoplay/radio best-effort al terminar la cola (repeat off).
    private func handleQueueEnded() {
        guard let provider = relatedProvider,
              let current = queue.current
        else { return }
        radioTask?.cancel()
        radioTask = Task { [weak self, queue, provider] in
            do {
                if let related = try await provider.next(after: current, playlist: queue.items) {
                    try Task.checkCancellation()
                    guard let self else { return }
                    await self.enqueueAndPlayRelated(related)
                }
            } catch {
                // Best-effort: ante error se mantiene detenido, sin error visible.
            }
        }
    }

    @MainActor
    private func enqueueAndPlayRelated(_ related: MediaItem) {
        // `play(_:)` encola (si no está) y sitúa la pista como actual.
        queue.play(related)
        load(related, autoplay: true, resetRetryBudget: true)
    }

    func previous() {
        guard let item = queue.retreat() else {
            seek(toSeconds: 0)
            return
        }
        load(item, autoplay: true, resetRetryBudget: true)
    }

    func removeFromQueue(id: MediaItem.ID) {
        let removedCurrentItem = queue.current?.id == id
        queue.remove(id: id)
        guard removedCurrentItem else { return }
        if let replacement = queue.current {
            load(replacement, autoplay: true, resetRetryBudget: true)
        } else {
            stop()
        }
    }

    func clearQueue() {
        queue.clear()
        stop()
    }

    func seek(to progress: Double) {
        guard duration > 0 else { return }
        seek(toSeconds: min(max(progress, 0), 1) * duration)
    }

    func seek(toSeconds seconds: Double) {
        guard seconds.isFinite else { return }
        let bounded = duration > 0 ? min(max(seconds, 0), duration) : max(seconds, 0)
        player.seek(
            to: CMTime(seconds: bounded, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = bounded
                self?.updateNowPlayingInfo()
            }
        }
    }

    private func stop() {
        resolveTask?.cancel()
        recoveryTask?.cancel()
        prefetchTask?.cancel()
        loadGeneration += 1
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemStatusObservation = nil
        #if os(iOS)
        artworkTask?.cancel()
        #endif
        persistPosition(throttled: false)
        currentTime = 0
        duration = 0
        playbackState = .idle
        errorMessage = nil
        deactivatePlatformAudioSession()
        updateNowPlayingInfo()
    }

    private func load(
        _ item: MediaItem,
        autoplay: Bool,
        resetRetryBudget: Bool
    ) {
        resolveTask?.cancel()
        if resetRetryBudget {
            recoveryTask?.cancel()
            automaticRetryAvailable = true
        }
        loadGeneration += 1
        let generation = loadGeneration
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemStatusObservation = nil
        currentTime = 0
        duration = 0
        playbackState = .resolving
        errorMessage = nil
        updateNowPlayingInfo(item: item)

        resolveTask = Task { [weak self] in
            guard let self else { return }
            do {
                // OFFLINE: comprobar si existe copia local antes de resolver en red
                if let localURL = offlineManager?.localURL(for: item.id) {
                    try Task.checkCancellation()
                    guard generation == loadGeneration else { return }
                    let playerItem = AVPlayerItem(url: localURL)
                    installStatusObservation(for: playerItem, mediaItem: item)
                    player.replaceCurrentItem(with: playerItem)
                    playbackState = .buffering
                    schedulePrefetch()
                    if autoplay, activatePlatformAudioSession() { player.play() }
                    return
                }

                let descriptor = try await resolver.resolve(videoID: item.id)
                try Task.checkCancellation()
                guard generation == loadGeneration else { return }

                let playerItem = AVPlayerItem(url: descriptor.streamURL)
                installStatusObservation(for: playerItem, mediaItem: item)
                player.replaceCurrentItem(with: playerItem)
                playbackState = .buffering
                schedulePrefetch()
                if autoplay, activatePlatformAudioSession() { player.play() }
            } catch is CancellationError {
                return
            } catch {
                guard generation == loadGeneration else { return }
                playbackState = .failed
                errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "No se pudo preparar esta canción."
                updateNowPlayingInfo(item: item)
            }
        }
    }

    private func observeQueueForPrefetch() {
        queueObservation = queue.$items
            .combineLatest(queue.$currentIndex)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.schedulePrefetch()
            }
    }

    private func schedulePrefetch() {
        prefetchTask?.cancel()
        guard player.currentItem != nil,
              let index = queue.currentIndex,
              queue.items.indices.contains(index + 1)
        else { return }

        let nextVideoID = queue.items[index + 1].id
        prefetchTask = Task { [resolver] in
            do {
                try await Task.sleep(nanoseconds: 150_000_000)
                try Task.checkCancellation()
                _ = try await resolver.resolve(videoID: nextVideoID)
            } catch {
                // La precarga es especulativa y nunca interrumpe la pista actual.
            }
        }
    }

    private func handlePlaybackFailure(for item: MediaItem) {
        guard automaticRetryAvailable else {
            playbackState = .failed
            errorMessage = "AVPlayer no pudo abrir la pista entregada por el VPS."
            updateNowPlayingInfo()
            return
        }

        automaticRetryAvailable = false
        let failedGeneration = loadGeneration
        playbackState = .resolving
        errorMessage = nil
        player.pause()
        player.replaceCurrentItem(with: nil)
        itemStatusObservation = nil

        recoveryTask?.cancel()
        recoveryTask = Task { [weak self] in
            guard let self else { return }
            await resolver.invalidate(videoID: item.id)
            try? Task.checkCancellation()
            guard !Task.isCancelled,
                  failedGeneration == loadGeneration,
                  queue.current?.id == item.id
            else { return }
            load(item, autoplay: true, resetRetryBudget: false)
        }
    }

    private func observePlayer() {
        periodicTimeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in self?.updateProgress(time) }
        }

        timeControlObservation = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in self?.handleTimeControlStatus(player.timeControlStatus) }
        }

        let endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let endedItem = notification.object as? AVPlayerItem else { return }
            Task { @MainActor [weak self, weak endedItem] in
                guard let self,
                      let endedItem,
                      endedItem === self.player.currentItem
                else { return }
                self.playbackState = .ended
                self.currentTime = self.duration
                self.updateNowPlayingInfo()
                self.handleEndOfPlayback()
            }
        }
        notificationObservers.append(endObserver)
    }

    private func installStatusObservation(for item: AVPlayerItem, mediaItem: MediaItem) {
        itemStatusObservation = item.observe(\.status, options: [.initial, .new]) { [weak self, weak item] observed, _ in
            Task { @MainActor [weak self, weak item, observed] in
                guard let self, let item, item === self.player.currentItem else { return }
                switch observed.status {
                case .readyToPlay:
                    self.updateDuration(from: observed)
                    if let pending = self.pendingSeekSeconds {
                        self.pendingSeekSeconds = nil
                        self.seek(toSeconds: pending)
                    }
                    if self.player.timeControlStatus != .playing {
                        self.playbackState = .paused
                    }
                    self.errorMessage = nil
                    self.updateNowPlayingInfo()
                case .failed:
                    self.handlePlaybackFailure(for: mediaItem)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func handleTimeControlStatus(_ status: AVPlayer.TimeControlStatus) {
        guard player.currentItem != nil else { return }
        switch status {
        case .playing:
            playbackState = .playing
            errorMessage = nil
        case .paused:
            if playbackState != .failed && playbackState != .resolving {
                playbackState = .paused
            }
        case .waitingToPlayAtSpecifiedRate:
            if playbackState != .resolving { playbackState = .buffering }
        @unknown default:
            break
        }
        updateNowPlayingInfo()
    }

    private func updateProgress(_ time: CMTime) {
        let seconds = time.seconds
        if seconds.isFinite { currentTime = max(0, seconds) }
        if let item = player.currentItem { updateDuration(from: item) }
        persistPosition(throttled: true)
        updateNowPlayingInfo()
    }

    /// Persiste la pista activa + posición si hay un `positionPersister` configurado.
    /// `throttled` limita la escritura periódica sin perder la escritura en pausa.
    private func persistPosition(throttled: Bool) {
        guard let current = queue.current else { return }
        if throttled, abs(currentTime - lastPersistedPosition) < 5.0 { return }
        lastPersistedPosition = currentTime
        positionPersister?(current, currentTime)
    }

    /// Restaura la reproducción tras reabrir: carga la pista y se posiciona sin
    /// auto-reproducción (queda en pausa).
    func restorePlayback(to item: MediaItem, at position: Double) {
        queue.play(item)
        pendingSeekSeconds = position
        load(item, autoplay: false, resetRetryBudget: true)
    }

    private func updateDuration(from item: AVPlayerItem) {
        let seconds = item.duration.seconds
        if seconds.isFinite && seconds > 0 { duration = seconds }
    }

    private func configurePlatformPlayback() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch {
            errorMessage = "iOS no pudo preparar la sesión de audio en segundo plano."
        }
        configureRemoteCommands()

        let interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                self?.handleInterruption(rawType: rawType, rawOptions: rawOptions)
            }
        }
        notificationObservers.append(interruptionObserver)
        #endif
    }

    @discardableResult
    private func activatePlatformAudioSession() -> Bool {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            return true
        } catch {
            playbackState = .failed
            errorMessage = "iOS no pudo activar la sesión de audio en segundo plano."
            return false
        }
        #else
        return true
        #endif
    }

    private func deactivatePlatformAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    #if os(iOS)
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        addTarget(to: center.playCommand) { [weak self] _ in
            guard self != nil else { return .commandFailed }
            Task { @MainActor [weak self] in self?.togglePlaybackIfPaused() }
            return .success
        }
        addTarget(to: center.pauseCommand) { [weak self] _ in
            guard self != nil else { return .commandFailed }
            Task { @MainActor [weak self] in self?.pauseFromRemote() }
            return .success
        }
        addTarget(to: center.nextTrackCommand) { [weak self] _ in
            guard self != nil else { return .commandFailed }
            Task { @MainActor [weak self] in self?.next() }
            return .success
        }
        addTarget(to: center.previousTrackCommand) { [weak self] _ in
            guard self != nil else { return .commandFailed }
            Task { @MainActor [weak self] in self?.previous() }
            return .success
        }
        addTarget(to: center.changePlaybackPositionCommand) { [weak self] event in
            guard self != nil,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            let position = positionEvent.positionTime
            Task { @MainActor [weak self] in self?.seek(toSeconds: position) }
            return .success
        }
    }

    private func addTarget(
        to command: MPRemoteCommand,
        handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus
    ) {
        let target = command.addTarget(handler: handler)
        remoteCommandTargets.append((command, target))
    }

    private func togglePlaybackIfPaused() {
        if !isPlaying { togglePlayback() }
    }

    private func pauseFromRemote() {
        if isPlaying { togglePlayback() }
    }

    private func handleInterruption(rawType: UInt?, rawOptions: UInt) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        if type == .began {
            playbackState = .paused
            updateNowPlayingInfo()
            return
        }

        if AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume),
           activatePlatformAudioSession() {
            player.play()
        }
    }
    #endif

    private func updateNowPlayingInfo(item explicitItem: MediaItem? = nil) {
        #if os(iOS)
        guard let item = explicitItem ?? queue.current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var information: [String: Any] = [
            MPMediaItemPropertyTitle: item.title,
            MPMediaItemPropertyArtist: item.channelTitle,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if duration > 0 { information[MPMediaItemPropertyPlaybackDuration] = duration }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = information
        publishArtwork(for: item)

        let center = MPRemoteCommandCenter.shared()
        center.nextTrackCommand.isEnabled = queue.canAdvance
        center.previousTrackCommand.isEnabled = queue.canRetreat || currentTime > 0
        #endif
    }

    #if os(iOS)
    /// Carga la carátula de forma asíncrona y la publica en Now Playing cuando
    /// está lista, sin bloquear el hilo principal. Los metadatos de texto ya se
    /// han publicado en `updateNowPlayingInfo`; aquí solo se añade la portada.
    private func publishArtwork(for item: MediaItem) {
        guard item.id != artworkItemID else { return }
        artworkItemID = item.id
        artworkTask?.cancel()
        guard let url = item.thumbnailURL else { return }
        artworkTask = Task { [weak self] in
            guard let self else { return }
            let image = await ArtworkCache.shared.image(for: url)
            guard !Task.isCancelled,
                  let image,
                  self.queue.current?.id == item.id
            else { return }
            let artwork = MPMediaItemArtwork(
                boundsSize: CGSize(width: CGFloat(image.width), height: CGFloat(image.height))
            ) { _ in
                UIImage(cgImage: image)
            }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
    #endif
}
