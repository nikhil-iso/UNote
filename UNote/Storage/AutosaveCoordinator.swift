import Combine
import Foundation

@MainActor
final class AutosaveCoordinator: ObservableObject {
    private let delay: Duration
    private let saveHandler: () async -> Void
    private var pendingTask: Task<Void, Never>?

    init(delay: Duration = .seconds(2), saveHandler: @escaping () async -> Void) {
        self.delay = delay
        self.saveHandler = saveHandler
    }

    deinit {
        pendingTask?.cancel()
    }

    func contentDidChange() {
        pendingTask?.cancel()
        pendingTask = Task { [delay, saveHandler] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else { return }
            await saveHandler()
        }
    }

    func saveImmediately() async {
        pendingTask?.cancel()
        pendingTask = nil
        await saveHandler()
    }
}
