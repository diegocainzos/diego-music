import Foundation

enum PlayerPlaybackState: Int, Codable, Equatable, Sendable {
    case unstarted = -1
    case ended = 0
    case playing = 1
    case paused = 2
    case buffering = 3
    case cued = 5
}

struct PlayerMessageEnvelope: Decodable, Equatable {
    let type: String
    let state: Int?
    let currentTime: Double?
    let duration: Double?
    let code: Int?
    let message: String?
}

enum PlayerEvent: Equatable {
    case ready
    case stateChanged(PlayerPlaybackState)
    case progress(current: Double, duration: Double)
    case failed(code: Int?, message: String?)

    init?(envelope: PlayerMessageEnvelope) {
        switch envelope.type {
        case "ready":
            self = .ready
        case "state":
            guard let raw = envelope.state, let state = PlayerPlaybackState(rawValue: raw) else { return nil }
            self = .stateChanged(state)
        case "progress":
            guard let current = envelope.currentTime, let duration = envelope.duration else { return nil }
            self = .progress(current: current, duration: duration)
        case "error":
            self = .failed(code: envelope.code, message: envelope.message)
        default:
            return nil
        }
    }
}

enum PlayerCommand: Encodable, Equatable {
    case load(videoID: String)
    case play
    case pause
    case seek(seconds: Double)

    enum CodingKeys: String, CodingKey { case type, videoID, seconds }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .load(videoID):
            try container.encode("load", forKey: .type)
            try container.encode(videoID, forKey: .videoID)
        case .play:
            try container.encode("play", forKey: .type)
        case .pause:
            try container.encode("pause", forKey: .type)
        case let .seek(seconds):
            try container.encode("seek", forKey: .type)
            try container.encode(seconds, forKey: .seconds)
        }
    }
}

struct PlayerMessageDecoder {
    func decode(body: Any) -> PlayerEvent? {
        guard JSONSerialization.isValidJSONObject(body),
              let data = try? JSONSerialization.data(withJSONObject: body),
              let envelope = try? JSONDecoder().decode(PlayerMessageEnvelope.self, from: data)
        else { return nil }
        return PlayerEvent(envelope: envelope)
    }
}
