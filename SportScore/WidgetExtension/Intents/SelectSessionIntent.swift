import AppIntents

struct SelectSessionIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Session"
    static let description = IntentDescription("Choose which active session to display.")

    @Parameter(title: "Session ID", default: "") var sessionID: String
}
