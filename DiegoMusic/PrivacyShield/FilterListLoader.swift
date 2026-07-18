import Foundation

enum FilterListLoaderError: LocalizedError, Equatable {
    case missingResource(String)
    case invalidData
    case emptyList

    var errorDescription: String? {
        switch self {
        case .missingResource:
            return "No se encontró una lista de reglas incluida."
        case .invalidData:
            return "La lista no tiene un formato compatible con WebKit."
        case .emptyList:
            return "La lista de reglas está vacía."
        }
    }
}

struct FilterListLoader {
    private let bundle: Bundle
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func rules(for mode: ShieldMode, customData: Data? = nil) throws -> [ContentBlockerRule] {
        guard mode != .off else { return [] }
        var result = try bundledRules(named: "balanced-rules")
        if mode == .aggressive {
            result.append(contentsOf: try bundledRules(named: "aggressive-rules"))
        }
        if let customData {
            result.append(contentsOf: try decode(customData))
        }
        guard !result.isEmpty else { throw FilterListLoaderError.emptyList }
        return result
    }

    func controlledRules() throws -> [ContentBlockerRule] {
        try bundledRules(named: "controlled-rules")
    }

    func encode(_ rules: [ContentBlockerRule]) throws -> String {
        let data = try encoder.encode(rules)
        guard let string = String(data: data, encoding: .utf8) else {
            throw FilterListLoaderError.invalidData
        }
        return string
    }

    func validateCustomList(_ data: Data) throws -> [ContentBlockerRule] {
        try decode(data)
    }

    private func bundledRules(named name: String) throws -> [ContentBlockerRule] {
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw FilterListLoaderError.missingResource(name)
        }
        return try decode(Data(contentsOf: url))
    }

    private func decode(_ data: Data) throws -> [ContentBlockerRule] {
        do {
            let rules = try decoder.decode([ContentBlockerRule].self, from: data)
            guard !rules.isEmpty else { throw FilterListLoaderError.emptyList }
            return rules
        } catch let error as FilterListLoaderError {
            throw error
        } catch {
            throw FilterListLoaderError.invalidData
        }
    }
}
