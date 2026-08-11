import SwiftUI

@main
struct DiegoMusicApp: App {
    private let persistence: PersistenceController
    @StateObject private var environment: AppEnvironment

    init() {
        let persistence = PersistenceController()
        self.persistence = persistence
        _environment = StateObject(
            wrappedValue: AppEnvironment(modelContext: persistence.container.viewContext)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
        }
        #if os(macOS)
        .defaultSize(width: 1180, height: 760)
        #endif
    }
}
