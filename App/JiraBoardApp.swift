import SwiftUI
import AppKit

/// The host app has no UI of its own — configuration lives in the widget itself
/// ("Edit Widget"). Its only job at runtime is to receive the URL a widget tap
/// delivers and hand it to the default browser, so clicking a task opens Jira on
/// the web instead of surfacing an app window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { NSWorkspace.shared.open(url) }
    }
}

@main
struct JiraBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
