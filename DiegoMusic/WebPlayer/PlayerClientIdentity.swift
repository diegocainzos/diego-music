import Foundation

struct PlayerClientIdentity: Equatable, Sendable {
    static let placeholder = "__APP_ORIGIN__"

    let origin: URL

    init(bundleIdentifier: String?) {
        let candidate = bundleIdentifier?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let appIdentifier = candidate.flatMap { $0.isEmpty ? nil : $0 }
            ?? "com.diegocainzos.diegomusic"
        origin = URL(string: "https://\(appIdentifier)")!
    }

    static func live(bundle: Bundle = .main) -> PlayerClientIdentity {
        PlayerClientIdentity(bundleIdentifier: bundle.bundleIdentifier)
    }

    func prepare(html: String) -> String {
        html.replacingOccurrences(of: Self.placeholder, with: origin.absoluteString)
    }
}
