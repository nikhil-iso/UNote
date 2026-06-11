import SwiftUI
import UIKit

extension Notification.Name {
    static let unoteShouldAutosaveNow = Notification.Name("UNoteShouldAutosaveNow")
}

@main
struct UNoteApp: App {
    @StateObject private var store = NotebookStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .task {
                    await store.refreshNotebooks()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background {
                        NotificationCenter.default.post(name: .unoteShouldAutosaveNow, object: nil)
                    }
                }
        }
    }
}
