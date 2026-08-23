import Foundation
import CoreServices

final class StoreFileWatcher {
    private var stream: FSEventStreamRef?
    private let storeDirectory: URL
    private let onChange: () -> Void

    init(storeDirectory: URL, onChange: @escaping () -> Void) {
        self.storeDirectory = storeDirectory
        self.onChange = onChange
    }

    func start() {
        guard stream == nil else { return }
        let path = storeDirectory.path as CFString
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagNoDefer
        )
        stream = FSEventStreamCreate(
            nil,
            { _, info, numEvents, eventPaths, eventFlags, _ in
                guard let info else { return }
                let watcher = Unmanaged<StoreFileWatcher>.fromOpaque(info).takeUnretainedValue()
                for index in 0..<numEvents {
                    let flags = eventFlags[index]
                    if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagItemIsFile) != 0 {
                        if let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String],
                           index < paths.count,
                           paths[index].hasSuffix(".gpg") {
                            DispatchQueue.main.async { watcher.onChange() }
                            return
                        }
                    }
                }
            },
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            flags
        )
        if let stream {
            FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(stream)
        }
    }

    func stop() {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    deinit {
        stop()
    }
}
