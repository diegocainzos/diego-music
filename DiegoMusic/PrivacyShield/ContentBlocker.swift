import Combine
import Foundation
import WebKit

@MainActor
final class ContentBlocker: ObservableObject {
    @Published private(set) var state: ShieldCompilationState = .idle

    private let store: WKContentRuleListStore
    private let loader: FilterListLoader
    private var applicationGeneration = 0

    init(store: WKContentRuleListStore = .default(), loader: FilterListLoader = FilterListLoader()) {
        self.store = store
        self.loader = loader
    }

    func apply(
        mode: ShieldMode,
        customData: Data?,
        to controller: WKUserContentController
    ) async {
        applicationGeneration += 1
        let generation = applicationGeneration

        guard mode != .off else {
            controller.removeAllContentRuleLists()
            state = .disabled
            return
        }

        state = .compiling
        do {
            let rules = try loader.rules(for: mode, customData: customData)
            let encoded = try loader.encode(rules)
            let identifier = "DiegoMusic.PrivacyShield.\(mode.rawValue)"
            let list = try await compile(identifier: identifier, encodedRules: encoded)
            guard generation == applicationGeneration else { return }
            controller.removeAllContentRuleLists()
            controller.add(list)
            state = .active(ruleCount: rules.count)
        } catch {
            guard generation == applicationGeneration else { return }
            state = .failed(message: sanitizedMessage(for: error))
        }
    }

    func compileControlledList() async throws -> WKContentRuleList {
        let rules = try loader.controlledRules()
        return try await compile(
            identifier: "DiegoMusic.PrivacyShield.controlled",
            encodedRules: loader.encode(rules)
        )
    }

    private func compile(identifier: String, encodedRules: String) async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            store.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: encodedRules
            ) { list, error in
                if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: error ?? FilterListLoaderError.invalidData)
                }
            }
        }
    }

    private func sanitizedMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "No se pudieron compilar las reglas. Se mantiene la reproducción sin esa lista."
    }
}
