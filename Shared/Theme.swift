import SwiftUI
import AppKit

/// Shared visual language, using Atlassian Design System colour tokens so the
/// widget reads as "Jira" in both light and dark appearance.
enum Theme {

    static let accent = Color(light: 0x0C66E4, dark: 0x579DFF)

    static let surfaceTop    = Color(light: 0xFFFFFF, dark: 0x22272B)
    static let surfaceBottom = Color(light: 0xF1F2F4, dark: 0x1D2125)

    static let skeleton  = Color(light: 0xDCDFE4, dark: 0x3A424B)
}

extension Color {

    init(hex: UInt) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >>  8) & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }

    init(light: UInt, dark: UInt) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
    }
}
