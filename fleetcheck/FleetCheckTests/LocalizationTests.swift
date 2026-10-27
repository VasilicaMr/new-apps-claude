import Foundation
import Testing
@testable import FleetCheck

@Suite("Localization")
struct LocalizationTests {
    static let languages = ["fr", "ro"]

    func bundle(_ language: String) throws -> Bundle {
        let path = try #require(Bundle.main.path(forResource: language, ofType: "lproj"))
        return try #require(Bundle(path: path))
    }

    func localized(_ value: String.LocalizationValue, _ language: String) throws -> String {
        String(localized: value, bundle: try bundle(language), locale: Locale(identifier: language))
    }

    @Test(arguments: languages)
    func translated(_ language: String) throws {
        #expect(try localized("Upload screenshot", language) != "Upload screenshot")
    }

    @Test("Romanian has three plural forms, French two")
    func plurals() throws {
        #expect(try localized("\(1) trips", "ro") == "1 cursă")
        #expect(try localized("\(3) trips", "ro") == "3 curse")
        #expect(try localized("\(20) trips", "ro") == "20 de curse")
        #expect(try localized("\(1) trips", "fr") == "1 course")
        #expect(try localized("\(5) trips", "fr") == "5 courses")
    }

    @Test("A plural in the middle of a sentence keeps the other arguments in place")
    func pluralWithOtherArguments() throws {
        #expect(try localized("Due in \(1) days, on \("3 novembre").", "fr") == "Échéance dans 1 jour, le 3 novembre.")
        #expect(try localized("\("ITP") is due in \(21) days.", "ro") == "ITP expiră peste 21 de zile.")
        #expect(try localized("of \("2 500 lei") · \(2) days left", "ro") == "din 2 500 lei · au mai rămas 2 zile")
    }

    /// Without Apple Intelligence the examples shown in the app go through the keyword parsers,
    /// so each translated example has to be understood the same way as the English one.
    @Test(arguments: languages)
    func translatedEntriesParse(_ language: String) throws {
        let parser = QuickEntryParser()
        for example: String.LocalizationValue in ["fuel $40 38 L at Shell", "car wash 35", "car wash $12 yesterday",
                                                  "parking $5", "uber 420 tips 30 bonus 50, 18 trips"] {
            let english = String(localized: example, bundle: try bundle("en"))
            let translated = try localized(example, language)
            let expected = try #require(parser.parse(english))
            let entry = try #require(parser.parse(translated), "\(translated)")
            switch (expected, entry) {
            case let (.expense(a), .expense(b)):
                #expect(a.category == b.category && a.daysAgo == b.daysAgo, "\(translated)")
            case let (.earning(a), .earning(b)):
                #expect(a.platform == b.platform && a.trips == b.trips && a.tips == b.tips && a.bonus == b.bonus, "\(translated)")
            default:
                Issue.record("\(translated) parsed as \(entry)")
            }
        }
    }

    @Test(arguments: languages)
    func translatedQuestionsParse(_ language: String) throws {
        let parser = AssistantCommandParser()
        for question: String.LocalizationValue in ["How much did I make this week?", "What was my net per hour last month?",
                                                   "How much did I spend on fuel this month?", "Which day pays best?",
                                                   "When is my ITP due?", "Which shifts are missing earnings?"] {
            let english = parser.parse(String(localized: question, bundle: try bundle("en")))
            let translated = try localized(question, language)
            #expect(parser.parse(translated) == english, "\(translated)")
        }
    }
}

/// The examples quoted in the App Store descriptions (AppStoreAssets/metadata) must work as written.
@Suite("Store description examples")
struct StoreDescriptionExampleTests {
    @Test(arguments: [("fuel $40 38 L", 40.0, 38.0), ("fuel 40 dollars 38 L", 40, 38), ("motorină 250 lei 34 L", 250, 34), ("carburant 70 € 38 L", 70, 38)])
    func quickEntries(_ text: String, amount: Double, liters: Double) throws {
        guard case let .expense(draft) = try #require(QuickEntryParser().parse(text)) else {
            Issue.record("\(text) isn't an expense"); return
        }
        #expect(draft.category == .fuel && draft.amount == amount && draft.liters == liters, "\(text)")
    }

    @Test(arguments: ["How much did I make this week?", "Cât am câștigat săptămâna asta?", "Combien j’ai gagné cette semaine ?"])
    func questions(_ text: String) {
        #expect(AssistantCommandParser().parse(text) == AssistantCommandParser().parse("How much did I make this week?"))
        #expect(AssistantCommandParser().parse(text) != nil, "\(text)")
    }
}
