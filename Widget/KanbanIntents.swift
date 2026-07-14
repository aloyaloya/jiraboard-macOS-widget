import AppIntents
import WidgetKit

struct NextColumnIntent: AppIntent {
    static var title: LocalizedStringResource = "Next column"
    func perform() async throws -> some IntentResult {
        let count = max(SharedStore.columnCount, 1)
        SharedStore.columnIndex = (SharedStore.columnIndex + 1) % count
        SharedStore.pageIndex = 0
        return .result()
    }
}

struct PrevColumnIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous column"
    func perform() async throws -> some IntentResult {
        let count = max(SharedStore.columnCount, 1)
        SharedStore.columnIndex = (SharedStore.columnIndex - 1 + count) % count
        SharedStore.pageIndex = 0
        return .result()
    }
}

struct NextPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Next tasks"
    func perform() async throws -> some IntentResult {
        SharedStore.pageIndex += 1
        return .result()
    }
}

struct PrevPageIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous tasks"
    func perform() async throws -> some IntentResult {
        SharedStore.pageIndex = max(0, SharedStore.pageIndex - 1)
        return .result()
    }
}
