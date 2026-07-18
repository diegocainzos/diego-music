import Foundation

struct AudioStreamDescriptor: Equatable, Sendable {
    let streamURL: URL
    let expiresAt: Date
    let contentType: String
}

protocol AudioStreamResolving: Sendable {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor
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

struct AudioResolverClient: AudioStreamResolving {
    let configuration: AudioResolverConfiguration
    let transport: any HTTPTransport

    init(
        configuration: AudioResolverConfiguration,
        transport: any HTTPTransport = URLSessionTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        guard videoID.count == 11,
              videoID.unicodeScalars.allSatisfy({
                  CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-").contains($0)
              })
        else {
            throw AudioResolverServiceError.invalidVideoID
        }

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
        } catch {
            throw AudioResolverServiceError.unavailable
        }

        switch response.statusCode {
        case 200:
            return try decodeDescriptor(from: data)
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

    private func decodeDescriptor(from data: Data) throws -> AudioStreamDescriptor {
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
              payload.expiresAt > Date(),
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

    private func safeServerMessage(from data: Data) -> String? {
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

struct UnavailableAudioResolver: AudioStreamResolving {
    func resolve(videoID: String) async throws -> AudioStreamDescriptor {
        throw AudioResolverServiceError.notConfigured
    }
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
