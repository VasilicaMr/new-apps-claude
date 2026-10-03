import AppIntents
import SwiftData

struct CaptureThoughtIntent: AppIntent {
    static var title: LocalizedStringResource = "Capture a Thought"
    static var description = IntentDescription("Save an idea or note without opening the app.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Thought")
    var content: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = try DataStore.makeContainer()
        let context = ModelContext(container)
        context.insert(Thought(content: content))
        try context.save()
        return .result(dialog: "Got it. Thought captured.")
    }
}
