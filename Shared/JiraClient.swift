import Foundation

/// Thin async wrapper over the Jira Cloud REST + Agile APIs.
/// Auth is HTTP Basic with `email:apiToken` (Atlassian Cloud).
struct JiraClient {
    let baseURL: String
    let email: String
    let apiToken: String

    enum JiraError: LocalizedError {
        case badURL
        case http(Int, String)
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .badURL: return "Invalid Jira URL"
            case .http(let code, let msg):
                if code == 401 || code == 403 { return "Authorization error (\(code))" }
                return "HTTP \(code): \(msg)"
            case .decoding(let m): return "Data error: \(m)"
            }
        }
    }

    private var authHeader: String {
        let raw = "\(email):\(apiToken)"
        let b64 = Data(raw.utf8).base64EncodedString()
        return "Basic \(b64)"
    }

    private func makeRequest(path: String, method: String = "GET", body: Data? = nil) throws -> URLRequest {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard let url = URL(string: "\(trimmed)\(path)") else { throw JiraError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(authHeader, forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return req
    }

    private func send(_ req: URLRequest) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw JiraError.http(-1, "no response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(200)) } ?? ""
            throw JiraError.http(http.statusCode, snippet)
        }
        return data
    }

    struct Board: Decodable, Identifiable, Hashable {
        let id: Int
        let name: String
    }

    func fetchBoards() async throws -> [Board] {
        struct Page: Decodable { let values: [Board]; let isLast: Bool?; let startAt: Int?; let maxResults: Int? }
        var all: [Board] = []
        var startAt = 0
        while true {
            let req = try makeRequest(path: "/rest/agile/1.0/board?startAt=\(startAt)&maxResults=50")
            let data = try await send(req)
            let page = try decode(Page.self, from: data)
            all.append(contentsOf: page.values)
            if page.isLast == true || page.values.isEmpty { break }
            startAt += page.values.count
            if startAt > 2000 { break } // safety
        }
        return all
    }

    func fetchColumns(boardId: Int) async throws -> [KanbanColumn] {
        struct Config: Decodable {
            struct ColumnConfig: Decodable {
                struct Column: Decodable {
                    struct Status: Decodable { let id: String }
                    let name: String
                    let statuses: [Status]?
                }
                let columns: [Column]
            }
            let columnConfig: ColumnConfig
        }
        let req = try makeRequest(path: "/rest/agile/1.0/board/\(boardId)/configuration")
        let data = try await send(req)
        let cfg = try decode(Config.self, from: data)
        return cfg.columnConfig.columns.map { col in
            KanbanColumn(name: col.name, statusIds: (col.statuses ?? []).map(\.id))
        }
    }

    func fetchMyIssues(statusIds: [String]) async throws -> [KanbanIssue] {
        guard !statusIds.isEmpty else { return [] }
        let statusList = statusIds.map { "\"\($0)\"" }.joined(separator: ",")
        let jql = "assignee = currentUser() AND status IN (\(statusList)) ORDER BY updated DESC"

        struct SearchBody: Encodable {
            let jql: String
            let fields: [String]
            let maxResults: Int
        }
        let body = try JSONEncoder().encode(
            SearchBody(jql: jql, fields: ["summary", "status"], maxResults: 100)
        )
        let req = try makeRequest(path: "/rest/api/3/search/jql", method: "POST", body: body)
        let data = try await send(req)

        struct SearchResult: Decodable {
            struct Issue: Decodable {
                struct Fields: Decodable {
                    struct Status: Decodable { let id: String? }
                    let summary: String?
                    let status: Status?
                }
                let key: String
                let fields: Fields
            }
            let issues: [Issue]
        }
        let result = try decode(SearchResult.self, from: data)
        return result.issues.map { issue in
            KanbanIssue(
                key: issue.key,
                summary: issue.fields.summary ?? "(no title)",
                statusId: issue.fields.status?.id ?? ""
            )
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw JiraError.decoding(String(describing: error)) }
    }
}
