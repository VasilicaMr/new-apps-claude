import Foundation

/// What the driver asked for, understood without Apple Intelligence.
/// Used for the instant suggestion chips, Siri, and as the fallback on iPhones without Apple Intelligence.
enum AssistantCommand: Sendable, Equatable {
    case stats(StatsPeriod, offset: Int)
    case compare(StatsPeriod)
    case spending(ExpenseCategory?, StatsPeriod, offset: Int)
    case bestDay
    case reminders
    case missingEarnings
    case add(QuickEntry)
    case unknown
}

struct AssistantCommandParser: Sendable {
    private let entries = QuickEntryParser()

    func parse(_ text: String) -> AssistantCommand {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let words = Set(folded.split { !$0.isLetter }.map(String.init))

        if !isQuestion(folded, words), let entry = entries.parse(text) { return .add(entry) }

        if !words.isDisjoint(with: ["due", "expire", "expires", "expiry", "reminder", "reminders", "itp", "rca", "casco",
                                    "rovinieta", "vignette", "expira", "scadent", "scadenta", "papers", "acte", "oil", "ulei"]) {
            return .reminders
        }
        let asksBest = !words.isDisjoint(with: ["best", "buna", "bune", "profitabil", "profitabila"])
        if (asksBest && !words.isDisjoint(with: ["day", "days", "time", "hours", "hour", "zi", "zile", "ora", "ore"]))
            || folded.contains("when should i") || folded.contains("cand sa") {
            return .bestDay
        }
        if folded.contains("missing") || folded.contains("forgot") || folded.contains("lipsa") || folded.contains("uitat") {
            return .missingEarnings
        }

        let (period, offset) = period(in: folded, words)
        if !words.isDisjoint(with: ["compare", "compared", "vs", "versus", "compar", "fata"]) {
            return .compare(period)
        }
        if !words.isDisjoint(with: ["spent", "spend", "spending", "cost", "costs", "expenses", "cheltuieli", "cheltuit", "costat"]) {
            let category = QuickEntryParser.category(in: words)
            return .spending(category, period, offset: offset)
        }
        if let category = QuickEntryParser.category(in: words), category != .other {
            return .spending(category, period, offset: offset)
        }
        if !words.isDisjoint(with: ["earn", "earned", "earnings", "made", "make", "net", "profit", "km", "kilometers", "hours",
                                    "castigat", "castiguri", "facut", "ore", "kilometri", "stats", "statistici", "how", "cat", "cati"])
            || hasPeriodWord(words) {
            return .stats(period, offset: offset)
        }
        return .unknown
    }

    private func isQuestion(_ folded: String, _ words: Set<String>) -> Bool {
        folded.contains("?") || !words.isDisjoint(with: ["how", "what", "when", "which", "show", "cat", "cand", "ce", "cum", "care", "arata"])
    }

    private func hasPeriodWord(_ words: Set<String>) -> Bool {
        !words.isDisjoint(with: ["today", "yesterday", "week", "month", "year", "azi", "astazi", "ieri", "saptamana", "saptamanii", "luna", "lunii", "anul"])
    }

    private func period(in folded: String, _ words: Set<String>) -> (StatsPeriod, Int) {
        let previous = !words.isDisjoint(with: ["last", "previous", "trecuta", "trecut", "precedenta"])
        if words.contains("yesterday") || words.contains("ieri") { return (.day, -1) }
        if words.contains("today") || words.contains("azi") || words.contains("astazi") { return (.day, 0) }
        if !words.isDisjoint(with: ["month", "luna", "lunii"]) { return (.month, previous ? -1 : 0) }
        if !words.isDisjoint(with: ["year", "anul", "an"]) { return (.year, previous ? -1 : 0) }
        return (.week, previous ? -1 : 0)
    }
}

extension QuickEntryParser {
    /// The expense category a set of folded words points to, if any.
    static func category(in words: Set<String>) -> ExpenseCategory? {
        let map: [(ExpenseCategory, [String])] = [
            (.fuel, ["fuel", "gas", "petrol", "diesel", "benzina", "motorina", "carburant"]),
            (.charging, ["charging", "incarcare"]),
            (.carWash, ["wash", "spalat", "spalatorie"]),
            (.maintenance, ["service", "revizie", "maintenance"]),
            (.repair, ["repair", "repairs", "reparatii", "reparatie"]),
            (.tyres, ["tyres", "tires", "anvelope"]),
            (.insurance, ["insurance", "asigurare"]),
            (.parking, ["parking", "parcare"]),
            (.fines, ["fines", "amenzi", "amenda"]),
        ]
        return map.first { !words.isDisjoint(with: $0.1) }?.0
    }
}
