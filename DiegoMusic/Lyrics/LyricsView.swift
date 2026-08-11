import SwiftUI

/// Vista de letras sincronizadas con auto-scroll.
///
/// Consume un `LyricsProviding` y el tiempo de reproducción actual para
/// resaltar y desplazar la línea activa. Degrada con elegancia (estado vacío)
/// cuando no hay letra o proveedor, sin interrumpir la reproducción.
struct LyricsView: View {
    let service: LyricsService
    let item: MediaItem
    let currentTime: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var segments: [LyricSegment]?
    @State private var loaded = false

    var body: some View {
        Group {
            if loaded {
                if let segments, !segments.isEmpty {
                    lyricsList(segments)
                } else {
                    emptyState
                }
            } else {
                ProgressView()
                    .tint(DiegoTheme.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: item.id) {
            segments = await service.lyrics(for: item, at: currentTime)
            loaded = true
        }
    }

    private var allLines: [LyricsLine] {
        (segments ?? []).flatMap(\.lines)
    }

    private var activeIndex: Int? {
        let lines = allLines
        // Última línea cuyo inicio ya fue alcanzado y aún no superado su final.
        // Con líneas sin marcas temporales (startTime == nil) devolvemos nil
        // para desactivar el auto-scroll.
        let timed = lines.enumerated().filter { $0.element.startTime != nil }
        guard let last = timed.last(where: {
            let start = $0.element.startTime ?? 0
            let end = $0.element.endTime ?? .greatestFiniteMagnitude
            return currentTime >= start && currentTime < end
        }) else {
            return timed.last(where: { ($0.element.startTime ?? 0) <= currentTime })?.offset
        }
        return last.offset
    }

    private func lyricsList(_ segments: [LyricSegment]) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(allLines.enumerated()), id: \.element.id) { index, line in
                        Text(line.text)
                            .font(.title3.weight(isActive(index) ? .semibold : .regular))
                            .foregroundStyle(isActive(index) ? DiegoTheme.textPrimary : DiegoTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.vertical, 24)
            }
            .onChange(of: activeIndex) { index in
                guard let index, allLines.indices.contains(index) else { return }
                let lineID = allLines[index].id
                if reduceMotion {
                    proxy.scrollTo(lineID, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(lineID, anchor: .center)
                    }
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Letras")
            .accessibilityValue(activeLineText ?? "Letra no disponible")
        }
    }

    private func isActive(_ index: Int) -> Bool {
        activeIndex == index
    }

    private var activeLineText: String? {
        guard let activeIndex, allLines.indices.contains(activeIndex) else { return nil }
        return allLines[activeIndex].text
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.quote")
                .font(.largeTitle)
                .foregroundStyle(DiegoTheme.textSecondary)
            Text("Letra no disponible")
                .font(.headline)
                .foregroundStyle(DiegoTheme.textPrimary)
            Text("La letra es opcional y best-effort; sin proveedor configurado no se muestra.")
                .font(.callout)
                .foregroundStyle(DiegoTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}
