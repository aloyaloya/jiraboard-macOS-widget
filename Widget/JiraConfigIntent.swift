import AppIntents
import WidgetKit
import Foundation

/// The widget's own configuration, edited via right-click → "Edit Widget".
/// WidgetKit passes these values to the timeline provider — no App Group needed,
/// so it works on a free Apple team.
///
/// Board and columns are plain Strings on purpose: an *entity* parameter inside a
/// dependent `@IntentParameterDependency` resolves the whole dependency to `nil`
/// in the macOS config sheet, whereas String parameters propagate correctly.
struct JiraConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Jira Board"
    static var description = IntentDescription("Connect your Jira account, then choose a board and the columns to show.")

    @Parameter(title: "Jira site URL",
               description: "Your Jira address, for example https://team.atlassian.net",
               default: "https://team.atlassian.net")
    var baseURL: String

    @Parameter(title: "Account email",
               description: "The email address of your Atlassian account",
               default: "")
    var email: String

    @Parameter(title: "API token",
               description: "Create one at id.atlassian.com → Security → API tokens",
               default: "")
    var apiToken: String

    @Parameter(title: "Board", optionsProvider: BoardOptionsProvider())
    var board: String?

    @Parameter(title: "Columns to show", optionsProvider: ColumnOptionsProvider())
    var columns: [String]?

    var boardId: Int { ConfigCache.boardId(forName: board ?? "") }

    var columnNames: [String] { columns ?? [] }

    var isComplete: Bool {
        !baseURL.isEmpty && !email.isEmpty && !apiToken.isEmpty
            && !(board ?? "").isEmpty && !(columns ?? []).isEmpty
    }
}

enum ConfigCache {
    private static var d: UserDefaults { .standard }

    static func saveBoardMap(_ map: [String: Int]) { d.set(map, forKey: "cfg.boardMap") }
    static func boardId(forName name: String) -> Int {
        (d.dictionary(forKey: "cfg.boardMap")?[name] as? Int) ?? 0
    }
}

struct BoardOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<JiraConfigIntent>(\.$baseURL, \.$email, \.$apiToken)
    var creds

    func results() async throws -> [String] {
        guard let creds,
              !creds.baseURL.isEmpty, !creds.email.isEmpty, !creds.apiToken.isEmpty
        else { return [] }
        let client = JiraClient(baseURL: creds.baseURL, email: creds.email, apiToken: creds.apiToken)
        let boards = try await client.fetchBoards()
        ConfigCache.saveBoardMap(Dictionary(boards.map { ($0.name, $0.id) },
                                            uniquingKeysWith: { first, _ in first }))
        return boards.map(\.name)
    }
}

struct ColumnOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<JiraConfigIntent>(\.$baseURL, \.$email, \.$apiToken, \.$board)
    var config

    func results() async throws -> [String] {
        guard let config,
              !config.baseURL.isEmpty, !config.email.isEmpty, !config.apiToken.isEmpty,
              !config.board.isEmpty
        else { return [] }
        let client = JiraClient(baseURL: config.baseURL, email: config.email, apiToken: config.apiToken)
        let boards = try await client.fetchBoards()
        guard let boardId = boards.first(where: { $0.name == config.board })?.id else { return [] }
        let cols = try await client.fetchColumns(boardId: boardId)
        return cols.map(\.name)
    }
}
