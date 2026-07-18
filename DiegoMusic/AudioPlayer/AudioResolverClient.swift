import Foundation

struct AudioStreamDescriptor: Equatable, Sendable {
    let streamURL: URL
    let expiresAt: Date
    let contentType: String
}

protocol AudioStreamResolving: Sendable {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor
    func invalidate(videoID: String) async
}

extension AudioStreamResolving {
    func invalidate(videoID: String) async {}
}

enum AudioResolverServiceError: LocalizedError, Equatable, Sendable {
    case notConfigured
    case invalidVideoID
    case unauthorized
    case rejected(String)
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Configura el resolutor privado en .env y vuelve a generar el proyecto."
        case .invalidVideoID:
            return "La canción no contiene un identificador de YouTube válido."
        case .unauthorized:
            return "El VPS rechazó la credencial. Comprueba que el token coincida."
        case let .rejected(message):
            return message
        case .unavailable:
            return "El servicio privado de audio no está disponible."
        case .invalidResponse:
            return "El servicio privado devolvió una respuesta no válida."
        }
    }
}

actor AudioResolverClient: AudioStreamResolving {
    let configuration: AudioResolverConfiguration
    let transport: any HTTPTransport

    private let expirationSafetyMargin: TimeInterval
    private let clock: @Sendable () -> Date
    private var descriptors: [String: AudioStreamDescriptor] = [:]
    private var inFlight: [String: PendingResolution] = [:]

    init(
        configuration: AudioResolverConfiguration,
        transport: any HTTPTransport = URLSessionTransport(),
        expirationSafetyMargin: TimeInterval = 90,
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configuration = configuration
        self.transport = transport
        self.expirationSafetyMargin = expirationSafetyMargin
        self.clock = clock
    }

    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        try Self.validate(videoID: videoID)
        let now = clock()
        if let cached = descriptors[videoID],
           cached.expiresAt.timeIntervalSince(now) > expirationSafetyMargin {
            return cached
        }
        descriptors.removeValue(forKey: videoID)

        if let pending = inFlight[videoID] {
            return try await pending.task.value
        }

        let identifier = UUID()
        let configuration = configuration
        let transport = transport
        let task = Task<AudioStreamDescriptor, Error> {
            try await Self.requestDescriptor(
                videoID: videoID,
                configuration: configuration,
                transport: transport,
                now: now
            )
        }
        inFlight[videoID] = PendingResolution(id: identifier, task: task)

        do {
            let descriptor = try await task.value
            if inFlight[videoID]?.id == identifier {
                inFlight.removeValue(forKey: videoID)
                if descriptor.expiresAt.timeIntervalSince(clock()) > expirationSafetyMargin {
                    descriptors[videoID] = descriptor
                }
            }
            return descriptor
        } catch {
            if inFlight[videoID]?.id == identifier {
                inFlight.removeValue(forKey: videoID)
            }
            throw error
        }
    }

    func invalidate(videoID: String) async {
        descriptors.removeValue(forKey: videoID)
        inFlight.removeValue(forKey: videoID)?.task.cancel()
    }

    var cacheEntryCount: Int {
        descriptors.count
    }

    private static func requestDescriptor(
        videoID: String,
        configuration: AudioResolverConfiguration,
        transport: any HTTPTransport,
        now: Date
    ) async throws -> AudioStreamDescriptor {
        let endpoint = configuration.baseURL
            .appendingPathComponent("v1")
            .appendingPathComponent("audio")
            .appendingPathComponent("resolve")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(ResolvePayload(videoID: videoID))

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AudioResolverServiceError.unavailable
        }

        switch response.statusCode {
        case 200:
            return try decodeDescriptor(from: data, now: now)
        case 401:
            throw AudioResolverServiceError.unauthorized
        case 422:
            let message = safeServerMessage(from: data)
                ?? "Este contenido no ofrece una pista de audio compatible."
            throw AudioResolverServiceError.rejected(message)
        case 500...599:
            throw AudioResolverServiceError.unavailable
        default:
            throw AudioResolverServiceError.invalidResponse
        }
    }

    private static func validate(videoID: String) throws {
        guard videoID.count == 11,
              videoID.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-").contains($0)
              })
        else {
            throw AudioResolverServiceError.invalidVideoID
        }
    }

    private static func decodeDescriptor(from data: Data, now: Date) throws -> AudioStreamDescriptor {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let regular = ISO8601DateFormatter()
            regular.formatOptions = [.withInternetDateTime]
            guard let date = fractional.date(from: value) ?? regular.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Fecha ISO-8601 inválida")
            }
            return date
        }

        let payload: ResolvePayloadResponse
        do {
            payload = try decoder.decode(ResolvePayloadResponse.self, from: data)
        } catch {
            throw AudioResolverServiceError.invalidResponse
        }
        guard payload.streamURL.scheme?.lowercased() == "https",
              payload.streamURL.host != nil,
              payload.expiresAt > now,
              payload.contentType.lowercased().hasPrefix("audio/")
        else {
            throw AudioResolverServiceError.invalidResponse
        }
        return AudioStreamDescriptor(
            streamURL: payload.streamURL,
            expiresAt: payload.expiresAt,
            contentType: payload.contentType
        )
    }

    private static func safeServerMessage(from data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(ServerErrorPayload.self, from: data) else { return nil }
        let message = payload.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = message.lowercased()
        guard !message.isEmpty,
              message.count <= 180,
              !lowered.contains("http://"),
              !lowered.contains("https://"),
              !lowered.contains("bearer"),
              !lowered.contains("token")
        else { return nil }
        return message
    }
}

private struct PendingResolution {
    let id: UUID
    let task: Task<AudioStreamDescriptor, Error>
}

struct UnavailableAudioResolver: AudioStreamResolving {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        throw AudioResolverServiceError.notConfigured
    }

    func invalidate(videoID: String) async {}
}

private struct ResolvePayload: Encodable {
    let videoID: String

    enum CodingKeys: String, CodingKey {
        case videoID = "videoId"
    }
}

private struct ResolvePayloadResponse: Decodable {
    let streamURL: URL
    let expiresAt: Date
    let contentType: String
}

private struct ServerErrorPayload: Decodable {
    let detail: String
}
