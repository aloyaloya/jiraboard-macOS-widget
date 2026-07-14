import Foundation
import WidgetKit

/// Widget-local state kept in the widget's own sandbox: the paging indices and
/// the cached snapshot. The Jira config isn't here - it lives in the widget's
/// `AppIntentConfiguration` (App Groups are unavailable on a free Apple team).
enum SharedStore {
    static let widgetKind = "JiraBoardWidget"

    private static var defaults: UserDefaults { .standard }

    private enum Key {
        static let columnIndex = "kanban.columnIndex"
        static let pageIndex = "kanban.pageIndex"
        static let columnCount = "kanban.columnCount"
    }

    /// Number of selected columns, written by the provider so the paging intents
    /// can wrap around without access to the widget configuration.
    static var columnCount: Int {
        get { defaults.integer(forKey: Key.columnCount) }
        set { defaults.set(newValue, forKey: Key.columnCount) }
    }

    static var columnIndex: Int {
        get { defaults.integer(forKey: Key.columnIndex) }
        set { defaults.set(newValue, forKey: Key.columnIndex) }
    }

    static var pageIndex: Int {
        get { defaults.integer(forKey: Key.pageIndex) }
        set { defaults.set(newValue, forKey: Key.pageIndex) }
    }

    private static var snapshotURL: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("kanban-snapshot.json")
    }

    static func loadSnapshot() -> KanbanSnapshot {
        guard let data = try? Data(contentsOf: snapshotURL),
              let snap = try? JSONDecoder().decode(KanbanSnapshot.self, from: data)
        else { return KanbanSnapshot() }
        return snap
    }

    static func saveSnapshot(_ snapshot: KanbanSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: snapshotURL, options: .atomic)
    }

    static func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }
}
