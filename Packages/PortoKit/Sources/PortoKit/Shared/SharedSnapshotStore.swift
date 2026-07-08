import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Reads/writes the `SharedSnapshot` JSON in the App Group container so the widget can render the
/// latest net worth even before (or without) a live fetch. On write, reloads widget timelines.
public struct SharedSnapshotStore: Sendable {
    private let appGroupID: String
    private let filename: String

    public init(appGroupID: String = AppConfig.appGroupIdentifier,
                filename: String = AppConfig.sharedSnapshotFilename) {
        self.appGroupID = appGroupID
        self.filename = filename
    }

    private var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(filename)
    }

    @discardableResult
    public func write(_ snapshot: SharedSnapshot) -> Bool {
        guard let url = fileURL else { return false }
        do {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            try enc.encode(snapshot).write(to: url, options: .atomic)
            reloadWidgets()
            return true
        } catch {
            return false
        }
    }

    public func read() -> SharedSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(SharedSnapshot.self, from: data)
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit) && os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
