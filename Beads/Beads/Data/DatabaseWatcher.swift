import Foundation

final class DatabaseWatcher: @unchecked Sendable {
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private let debounceInterval: TimeInterval = 0.15
    private var debounceWorkItem: DispatchWorkItem?
    private let onChange: @MainActor () -> Void

    init(directory: String, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        startWatching(directory: directory)
    }

    private func startWatching(directory: String) {
        // Watch the directory itself (catches file creation/deletion, e.g. journal mode)
        watchPath(directory)

        // Watch the database file and WAL file directly.
        // In WAL mode, writes go to the -wal file without triggering directory events.
        let dbFile = (directory as NSString).appendingPathComponent("beads.db")
        let walFile = dbFile + "-wal"
        watchPath(dbFile)
        watchPath(walFile)
    }

    private func watchPath(_ path: String) {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: .global(qos: .utility)
        )

        source.setEventHandler { [weak self] in
            self?.scheduleDebounce()
        }

        source.setCancelHandler {
            close(fd)
        }

        fileDescriptors.append(fd)
        sources.append(source)
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
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }

    deinit {
        stop()
    }
}
