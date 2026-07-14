import SwiftUI
import WidgetKit
import AppIntents

struct KanbanEntryView: View {
    var entry: KanbanEntry

    private let pageSize = 5

    private var columns: [KanbanColumn] { entry.config.columns }

    private var currentColumn: KanbanColumn? {
        guard columns.indices.contains(entry.columnIndex) else { return columns.first }
        return columns[entry.columnIndex]
    }

    private var columnIssues: [KanbanIssue] {
        guard let col = currentColumn else { return [] }
        return entry.snapshot.issues(in: col)
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(columnIssues.count) / Double(pageSize))))
    }

    private var clampedPage: Int { min(entry.pageIndex, pageCount - 1) }

    private var hasTaskPaging: Bool { columnIssues.count > pageSize }

    private var pageIssues: ArraySlice<KanbanIssue> {
        let start = clampedPage * pageSize
        let end = min(start + pageSize, columnIssues.count)
        guard start < end else { return columnIssues[0..<0] }
        return columnIssues[start..<end]
    }

    private var isLoading: Bool {
        entry.snapshot.fetchedAt == .distantPast && entry.snapshot.errorMessage == nil
    }

    private var isEmptyColumn: Bool { !isLoading && columnIssues.isEmpty }

    private let contentMargin: CGFloat = 16

    var body: some View {
        Group {
            if !entry.config.isComplete {
                unconfigured
            } else {
                configured
            }
        }
        .padding(contentMargin)
        .containerBackground(for: .widget) { background }
    }

    private var configured: some View {
        // Greedy top-anchored frame (works only because content margins are
        // disabled); the Spacer then pins the footer to the bottom. The empty
        // state centres itself and fills the gap, so it skips the Spacer.
        VStack(alignment: .leading, spacing: 10) {
            header
            content
            if !isEmptyColumn { Spacer(minLength: 0) }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder private var content: some View {
        if isLoading {
            skeletonList
        } else if columnIssues.isEmpty {
            emptyColumn
        } else {
            issueList
        }
    }

    private var issueList: some View {
        VStack(spacing: 0) {
            ForEach(Array(pageIssues.enumerated()), id: \.element.id) { index, issue in
                IssueRow(issue: issue, url: issueURL(issue.key))
                if index < pageIssues.count - 1 { rowSeparator }
            }
        }
    }

    private var skeletonList: some View {
        VStack(spacing: 0) {
            ForEach(0..<pageSize, id: \.self) { i in
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                        .fill(Theme.skeleton)
                        .frame(width: skeletonTitleWidth(i), height: 11)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.skeleton)
                        .frame(width: 44, height: 9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 2)
                .padding(.vertical, 8)
                if i < pageSize - 1 { rowSeparator }
            }
        }
    }

    private func skeletonTitleWidth(_ i: Int) -> CGFloat {
        [150, 110, 170, 90, 130][i % 5]
    }

    private var rowSeparator: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.22))
            .frame(height: 0.5)
            .padding(.leading, 2)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(currentColumn?.name ?? "")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .lineLimit(1)

            Spacer(minLength: 4)

            if isLoading {
                Capsule()
                    .fill(Theme.skeleton)
                    .frame(width: 24, height: 18)
            } else {
                Text("\(columnIssues.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(Capsule().fill(Theme.accent.opacity(0.14)))
            }
        }
    }

    private func navButton<I: AppIntent>(intent: I, icon: String, align: Alignment) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 34, alignment: align)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var footer: some View {
        if let err = entry.snapshot.errorMessage {
            Label(err, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.orange)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        } else {
            HStack(spacing: 0) {
                if columns.count > 1 {
                    navButton(intent: PrevColumnIntent(), icon: "chevron.left", align: .leading)
                }
                Spacer(minLength: 0)
                HStack(spacing: 10) {
                    if hasTaskPaging {
                        pagerButton(intent: PrevPageIntent(), icon: "chevron.up",
                                    disabled: clampedPage == 0)
                    }
                    if columns.count > 1 {
                        ColumnDots(count: columns.count, index: entry.columnIndex)
                    }
                    if hasTaskPaging {
                        pagerButton(intent: NextPageIntent(), icon: "chevron.down",
                                    disabled: clampedPage >= pageCount - 1)
                    }
                }
                Spacer(minLength: 0)
                if columns.count > 1 {
                    navButton(intent: NextColumnIntent(), icon: "chevron.right", align: .trailing)
                }
            }
            .frame(minHeight: 26)
        }
    }

    private func pagerButton<I: AppIntent>(intent: I, icon: String, disabled: Bool) -> some View {
        Button(intent: intent) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.25 : 1)
    }

    private var emptyColumn: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("No tasks assigned")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var unconfigured: some View {
        VStack(spacing: 8) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            Text("Set up your Jira")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Text("Right-click the widget → “Edit Widget”, then add your Jira URL, account email and API token.")
                .multilineTextAlignment(.center)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private var trimmedBase: String {
        entry.config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: " /"))
    }

    private func issueURL(_ key: String) -> URL? {
        guard !trimmedBase.isEmpty else { return nil }
        return URL(string: "\(trimmedBase)/browse/\(key)")
    }

    private var background: some View {
        LinearGradient(
            colors: [Theme.surfaceTop, Theme.surfaceBottom],
            startPoint: .top, endPoint: .bottom
        )
    }
}

private struct IssueRow: View {
    let issue: KanbanIssue
    let url: URL?

    private var row: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(issue.summary)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(issue.key)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    var body: some View {
        if let url {
            Link(destination: url) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

private struct ColumnDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Theme.accent : Color.secondary.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
