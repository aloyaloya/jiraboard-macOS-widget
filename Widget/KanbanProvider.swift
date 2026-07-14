import WidgetKit
import SwiftUI

struct KanbanEntry: TimelineEntry {
    let date: Date
    let config: JiraConfig
    let snapshot: KanbanSnapshot
    let columnIndex: Int
    let pageIndex: Int
}

struct KanbanProvider: AppIntentTimelineProvider {
    typealias Entry = KanbanEntry
    typealias Intent = JiraConfigIntent

    /// How stale the cache may be before we refetch from Jira.
    private let cacheTTL: TimeInterval = 15 * 60

    func placeholder(in context: Context) -> KanbanEntry {
        // Empty snapshot (fetchedAt == .distantPast) → the view shows its
        // shape-based skeleton instead of a redacted blob.
        KanbanEntry(date: Date(), config: SampleData.config, snapshot: KanbanSnapshot(),
                    columnIndex: 0, pageIndex: 0)
    }

    func snapshot(for configuration: JiraConfigIntent, in context: Context) async -> KanbanEntry {
        if context.isPreview {
            return placeholder(in: context)
        }
        // Not-yet-configured widget → empty config so the view shows the "set up
        // your Jira" prompt rather than an endless skeleton.
        if !configuration.isComplete {
            return makeEntry(config: configFrom(configuration, columns: []), snapshot: KanbanSnapshot())
        }
        let snapshot = SharedStore.loadSnapshot()
        return makeEntry(config: configFrom(configuration, columns: snapshot.columns), snapshot: snapshot)
    }

    func timeline(for configuration: JiraConfigIntent, in context: Context) async -> Timeline<KanbanEntry> {
        guard configuration.isComplete else {
            let entry = makeEntry(config: configFrom(configuration, columns: []), snapshot: KanbanSnapshot())
            return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        }

        var snapshot = SharedStore.loadSnapshot()
        let stale = Date().timeIntervalSince(snapshot.fetchedAt) > cacheTTL || snapshot.columns.isEmpty
        if stale {
            snapshot = await refresh(configuration, previous: snapshot)
            SharedStore.saveSnapshot(snapshot)
        }
        let entry = makeEntry(config: configFrom(configuration, columns: snapshot.columns), snapshot: snapshot)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(cacheTTL)))
    }

    private func configFrom(_ intent: JiraConfigIntent, columns: [KanbanColumn]) -> JiraConfig {
        JiraConfig(baseURL: intent.baseURL, email: intent.email, apiToken: intent.apiToken,
                   boardId: intent.boardId, columns: columns)
    }

    private func makeEntry(config: JiraConfig, snapshot: KanbanSnapshot) -> KanbanEntry {
        SharedStore.columnCount = config.columns.count
        let colCount = max(config.columns.count, 1)
        let clampedCol = min(max(SharedStore.columnIndex, 0), colCount - 1)
        return KanbanEntry(date: Date(), config: config, snapshot: snapshot,
                           columnIndex: clampedCol, pageIndex: max(SharedStore.pageIndex, 0))
    }

    private func refresh(_ intent: JiraConfigIntent, previous: KanbanSnapshot) async -> KanbanSnapshot {
        let client = JiraClient(baseURL: intent.baseURL, email: intent.email, apiToken: intent.apiToken)
        do {
            // Resolve the board id from its name (cache first, then by fetching).
            var boardId = intent.boardId
            if boardId == 0 {
                let boards = (try? await client.fetchBoards()) ?? []
                boardId = boards.first(where: { $0.name == intent.board })?.id ?? 0
            }
            // Map the selected column names to the board's actual statuses.
            let boardCols = try await client.fetchColumns(boardId: boardId)
            let selected: [KanbanColumn] = intent.columnNames.map { wanted in
                if let m = boardCols.first(where: { $0.name.caseInsensitiveCompare(wanted) == .orderedSame }) {
                    return KanbanColumn(name: m.name, statusIds: m.statusIds)
                }
                return KanbanColumn(name: wanted, statusIds: [])
            }
            let issues = try await client.fetchMyIssues(statusIds: selected.flatMap(\.statusIds))
            return KanbanSnapshot(issues: issues, columns: selected, fetchedAt: Date(), errorMessage: nil)
        } catch {
            return KanbanSnapshot(issues: previous.issues, columns: previous.columns,
                                  fetchedAt: previous.fetchedAt,
                                  errorMessage: (error as? JiraClient.JiraError)?.errorDescription
                                    ?? error.localizedDescription)
        }
    }
}

enum SampleData {
    static let cols = [
        KanbanColumn(name: "TO DO", statusIds: ["1"]),
        KanbanColumn(name: "IN PROGRESS", statusIds: ["2"]),
        KanbanColumn(name: "REVIEW", statusIds: ["3"]),
        KanbanColumn(name: "TEST", statusIds: ["4"])
    ]
    static let config = JiraConfig(baseURL: "https://team.atlassian.net", email: "you@team.com",
                                   apiToken: "•••", boardId: 1, columns: cols)
}
