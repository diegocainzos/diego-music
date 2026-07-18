import Foundation

enum ShieldMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "Desactivado"
        case .balanced: return "Equilibrado"
        case .aggressive: return "Agresivo"
        }
    }

    var explanation: String {
        switch self {
        case .off:
            return "No instala reglas; útil para diagnosticar problemas."
        case .balanced:
            return "Bloquea redes publicitarias conocidas con prioridad a la reproducción."
        case .aggressive:
            return "Añade patrones de anuncios de YouTube y puede requerir recuperación."
        }
    }
}

struct ContentBlockerRule: Codable, Equatable, Sendable {
    struct Trigger: Codable, Equatable, Sendable {
        let urlFilter: String
        let resourceType: [String]?
        let ifDomain: [String]?
        let unlessDomain: [String]?

        enum CodingKeys: String, CodingKey {
            case urlFilter = "url-filter"
            case resourceType = "resource-type"
            case ifDomain = "if-domain"
            case unlessDomain = "unless-domain"
        }
    }

    struct Action: Codable, Equatable, Sendable {
        let type: String
    }

    let trigger: Trigger
    let action: Action
}

enum ShieldCompilationState: Equatable {
    case idle
    case compiling
    case active(ruleCount: Int)
    case disabled
    case failed(message: String)
}
