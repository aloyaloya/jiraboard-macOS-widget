import SwiftUI

/// The host app only needs to exist so the widget can be installed. All Jira
/// configuration happens in the widget itself (right-click → Edit Widget),
/// because a free Apple team can't share data between the app and the widget.
struct ContentView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                card("Add the widget") {
                    step(1, "Right-click the desktop → “Edit Widgets”.")
                    step(2, "Find “Jira Board” and drag it onto the desktop.")
                }
                card("Configure Jira") {
                    step(1, "Right-click the widget → “Edit Widget”.")
                    step(2, "Enter the URL (https://team.atlassian.net), Email and API token, then pick your board and columns from the dropdowns.")
                    step(3, "Done — the widget shows the tasks assigned to you.")
                    Link("Create an API token →",
                         destination: URL(string: "https://id.atlassian.com/manage-profile/security/api-tokens")!)
                        .font(.caption)
                }
                card("Controls") {
                    bullet("‹ / › at the bottom — switch board columns.")
                    bullet("↑ / ↓ at the bottom — page through tasks in a column.")
                    bullet("Click a task to open it in Jira.")
                }
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 22)).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("JiraBoard").font(.title2.bold())
                Text("Your Jira board on the desktop")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }

    private func card<Content: View>(_ heading: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(heading).font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(.background.secondary))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator))
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.accent))
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•").foregroundStyle(Theme.accent)
            Text(text).font(.callout)
        }
    }
}
