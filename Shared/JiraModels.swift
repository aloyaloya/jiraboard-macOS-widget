import Foundation

// MARK: - Configuration shared between the host app and the widget.

/// A single board column the user chose to show, with the Jira statuses it maps to.
struct KanbanColumn: Codable, Hashable, Identifiable {
    var name: String
    var statusIds: [String]
    var id: String { name }
}

/// Everything the widget needs to talk to Jira.
struct JiraConfig: Codable, Equatable {
    var baseURL: String = ""
    var email: String = ""
    var apiToken: String = ""
    var boardId: Int = 0
    var columns: [KanbanColumn] = []

    var isComplete: Bool {
        !baseURL.isEmpty && !email.isEmpty && !apiToken.isEmpty && boardId != 0 && !columns.isEmpty
    }
}

// MARK: - Domain models used for rendering.

/// A flattened Jira issue ready to render in a widget row.
struct KanbanIssue: Codable, Hashable, Identifiable {
    var key: String          // "DEV-1239"
    var summary: String
    var statusId: String
    var id: String { key }
}

/// The cached snapshot the widget renders from, refreshed on a timeline schedule.
struct KanbanSnapshot: Codable, Equatable {
    var issues: [KanbanIssue] = []
    /// Resolved columns (name → statuses) captured at fetch time, so paging is
    /// instant from cache without re-hitting the board-config endpoint.
    var columns: [KanbanColumn] = []
    var fetchedAt: Date = .distantPast
    var errorMessage: String? = nil

    func issues(in column: KanbanColumn) -> [KanbanIssue] {
        let ids = Set(column.statusIds)
        return issues.filter { ids.contains($0.statusId) }
    }
}
