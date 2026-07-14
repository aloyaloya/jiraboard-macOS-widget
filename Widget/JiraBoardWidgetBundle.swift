import WidgetKit
import SwiftUI

@main
struct JiraBoardWidgetBundle: WidgetBundle {
    var body: some Widget {
        JiraBoardWidget()
    }
}

struct JiraBoardWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: SharedStore.widgetKind,
                               intent: JiraConfigIntent.self,
                               provider: KanbanProvider()) { entry in
            KanbanEntryView(entry: entry)
        }
        .configurationDisplayName("Jira Board")
        .description("Your assigned Jira issues, grouped by board column.")
        .supportedFamilies([.systemLarge])
        // Disable system content margins (re-added in KanbanEntryView): the stock
        // wrapper centres short content and fights our top-pinned header layout.
        .contentMarginsDisabled()
    }
}
