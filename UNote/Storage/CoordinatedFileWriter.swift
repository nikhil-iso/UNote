import Foundation

enum CoordinatedFileWriter {
    static func write(_ data: Data, to url: URL) async throws {
        try await Task.detached(priority: .background) {
            try writeSynchronously(data, to: url)
        }.value
    }

    static func writeSynchronously(_ data: Data, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var writeError: Error?

        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinatorError) { coordinatedURL in
            do {
                try data.write(to: coordinatedURL, options: .atomic)
            } catch {
                writeError = error
            }
        }

        if let writeError {
            throw writeError
        }
        if let coordinatorError {
            throw coordinatorError
        }
    }
}
