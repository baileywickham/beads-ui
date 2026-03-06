import Foundation

final class PollingWatcher {
    private let interval: TimeInterval
    private let onChange: @MainActor () -> Void
    private var task: Task<Void, Never>?

    init(interval: TimeInterval = 2.0, onChange: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.onChange = onChange
    }

    func start() {
        guard task == nil else { return }
        let interval = self.interval
        let onChange = self.onChange
        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await onChange()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
