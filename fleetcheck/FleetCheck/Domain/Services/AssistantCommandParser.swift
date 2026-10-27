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
                                    "rovinieta", "vignette", "expira", "scadent", "scadenta", "papers", "acte", "oil", "ulei",
                                    "echeance", "rappel", "rappels", "papiers", "vidange", "controle"]) {
            return .reminders
        }
        let asksBest = !words.isDisjoint(with: ["best", "buna", "bune", "profitabil", "profitabila", "meilleur", "meilleure", "rentable"])
        if (asksBest && !words.isDisjoint(with: ["day", "days", "time", "hours", "hour", "zi", "zile", "ora", "ore",
                                                 "jour", "jours", "heure", "heures", "moment"]))
            || folded.contains("when should i") || folded.contains("cand sa") || folded.contains("quand dois") {
            return .bestDay
        }
        if ["missing", "forgot", "lipsa", "uitat", "nu au castig", "fara castig", "manque", "oublie", "pas de gain", "sans gain"]
            .contains(where: folded.contains) {
            return .missingEarnings
        }

        let (period, offset) = period(in: folded, words)
        if !words.isDisjoint(with: ["compare", "compared", "vs", "versus", "compar", "fata", "comparer", "comparaison"]) {
            return .compare(period)
        }
        if !words.isDisjoint(with: ["spent", "spend", "spending", "cost", "costs", "expenses", "cheltuieli", "cheltuit", "costat",
                                    "depense", "depenses", "frais", "coute", "couts"]) {
            let category = QuickEntryParser.category(in: words)
            return .spending(category, period, offset: offset)
        }
        if let category = QuickEntryParser.category(in: words), category != .other {
            return .spending(category, period, offset: offset)
        }
        if !words.isDisjoint(with: ["earn", "earned", "earnings", "made", "make", "net", "profit", "km", "kilometers", "hours",
                                    "castigat", "castiguri", "facut", "ore", "kilometri", "stats", "statistici", "how", "cat", "cati",
                                    "gagne", "gains", "benefice", "heures", "kilometres", "combien", "statistiques"])
            || hasPeriodWord(words) {
            return .stats(period, offset: offset)
        }
        return .unknown
    }

    private func isQuestion(_ folded: String, _ words: Set<String>) -> Bool {
        folded.contains("?") || !words.isDisjoint(with: ["how", "what", "when", "which", "show", "cat", "cand", "ce", "cum", "care", "arata",
                                                          "combien", "quand", "quel", "quelle", "quels", "comment", "montre"])
    }

    private func hasPeriodWord(_ words: Set<String>) -> Bool {
        !words.isDisjoint(with: ["today", "yesterday", "week", "month", "year", "azi", "astazi", "ieri", "saptamana", "saptamanii", "luna", "lunii", "anul",
                                 "aujourd", "hier", "semaine", "mois", "annee"])
    }

    private func period(in folded: String, _ words: Set<String>) -> (StatsPeriod, Int) {
        let previous = !words.isDisjoint(with: ["last", "previous", "trecuta", "trecut", "precedenta", "dernier", "derniere", "precedent", "precedente", "passe", "passee"])
        if !words.isDisjoint(with: ["yesterday", "ieri", "hier"]) { return (.day, -1) }
        if !words.isDisjoint(with: ["today", "azi", "astazi", "aujourd"]) { return (.day, 0) }
        if !words.isDisjoint(with: ["month", "luna", "lunii", "mois"]) { return (.month, previous ? -1 : 0) }
        if !words.isDisjoint(with: ["year", "anul", "an", "annee"]) { return (.year, previous ? -1 : 0) }
        return (.week, previous ? -1 : 0)
    }
}

extension QuickEntryParser {
    /// The expense category a set of folded words points to, if any.
    static func category(in words: Set<String>) -> ExpenseCategory? {
        let map: [(ExpenseCategory, [String])] = [
            (.fuel, ["fuel", "gas", "petrol", "diesel", "benzina", "motorina", "carburant", "essence", "gazole"]),
            (.charging, ["charging", "incarcare", "recharge"]),
            (.carWash, ["wash", "spalat", "spalatorie", "lavage"]),
            (.maintenance, ["service", "revizie", "maintenance", "entretien"]),
            (.repair, ["repair", "repairs", "reparatii", "reparatie", "reparation", "reparations"]),
            (.tyres, ["tyres", "tires", "anvelope", "pneus"]),
            (.insurance, ["insurance", "asigurare", "assurance"]),
            (.parking, ["parking", "parcare", "stationnement"]),
            (.fines, ["fines", "amenzi", "amenda", "amendes", "amende"]),
        ]
        return map.first { !words.isDisjoint(with: $0.1) }?.0
    }
}
