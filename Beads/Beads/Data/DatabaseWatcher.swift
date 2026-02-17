import Foundation

final class DatabaseWatcher: @unchecked Sendable {
    private var source: DispatchSourceFileSystemObject?
    private var dirFD: Int32 = -1
    private let debounceInterval: TimeInterval = 0.15
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: @MainActor () -> Void

    init(directory: String, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        startWatching(directory: directory)
    }

    private func startWatching(directory: String) {
        dirFD = open(directory, O_EVTONLY)
        guard dirFD >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: dirFD,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebounce()
        }

        source.setCancelHandler { [weak self] in
            if let fd = self?.dirFD, fd >= 0 {
                close(fd)
            }
        }

        self.source = source
        source.resume()
    }

    private func scheduleDebounce() {
        debounceWorkItem?.cancel()
        let onChange = self.onChange
        let work = DispatchWorkItem {
            DispatchQueue.main.async {
                onChange()
            }
        }
        debounceWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(
            deadline: .now() + debounceInterval, execute: work)
    }

    func stop() {
        debounceWorkItem?.cancel()
        source?.cancel()
        source = nil
    }

    deinit {
        stop()
    }
}
