import Foundation

/// A piece of text found on a screenshot with its position (normalized 0–1, origin top-left).
struct TextFragment: Sendable, Hashable {
    let text: String
    let minX: Double
    let midY: Double
    let height: Double
}

/// Turns OCR fragments into readable lines and pulls earnings out of them with keyword matching.
///
/// This is the fallback when Apple Intelligence isn't available, and it also builds the clean text
/// the language model reads. It understands English and Romanian labels and both number styles
/// ("1.234,56 lei" and "RON 1,234.56").
struct EarningsTextParser: Sendable {

    // MARK: - Lines

    /// Earnings screens are two columns ("Tips ........ 12,50 lei"). OCR returns the label and the
    /// amount as separate fragments, so fragments on the same row are joined left to right.
    func lines(from fragments: [TextFragment]) -> [String] {
        let sorted = fragments.sorted { $0.midY < $1.midY }
        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let last = rows.last?.last,
               abs(fragment.midY - last.midY) < max(fragment.height, last.height) * 0.6 {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: "  ")
        }
    }

    // MARK: - Amounts

    /// Parses "1.234,56", "1,234.56", "12,50", "€ 45", "-3.20 lei" to a number.
    func amount(in token: String) -> Double? {
        let cleaned = token.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard cleaned.contains(where: \.isNumber) else { return nil }
        let negative = cleaned.hasPrefix("-")
        var digits = cleaned.replacingOccurrences(of: "-", with: "")

        let lastDot = digits.lastIndex(of: ".")
        let lastComma = digits.lastIndex(of: ",")
        let decimalSeparator: Character?
        switch (lastDot, lastComma) {
        case let (dot?, comma?): decimalSeparator = dot > comma ? "." : ","
        case let (dot?, nil): decimalSeparator = isDecimal(digits, at: dot) ? "." : nil
        case let (nil, comma?): decimalSeparator = isDecimal(digits, at: comma) ? "," : nil
        case (nil, nil): decimalSeparator = nil
        }
        if let decimalSeparator {
            let thousands: Character = decimalSeparator == "." ? "," : "."
            digits.removeAll { $0 == thousands }
            digits = digits.replacingOccurrences(of: String(decimalSeparator), with: ".")
        } else {
            digits.removeAll { $0 == "." || $0 == "," }
        }
        guard let value = Double(digits) else { return nil }
        return negative ? -value : value
    }

    /// With only one kind of separator: repeated ("1.234.567") or followed by exactly 3 digits ("1.234")
    /// means thousands; otherwise ("12,50", "3.5") it is the decimal separator.
    private func isDecimal(_ digits: String, at index: String.Index) -> Bool {
        let separator = digits[index]
        guard digits.filter({ $0 == separator }).count == 1 else { return false }
        return digits[digits.index(after: index)...].count != 3
    }

    /// Optional currency, digits with thousands groups (dot, comma, no-break space), optional 1–2 decimals.
    private static let moneyPattern = #"(?:[€$£]|RON|lei|EUR)?\s?-?\d+(?:[.,\x{00A0}]\d{3})*(?:[.,]\d{1,2})?\s?(?:RON|lei|EUR|€)?"#

    /// Money amounts in a line, in reading order. Plain small integers without decimals or currency
    /// (like "15" trips or "7 h") are skipped.
    func amounts(in line: String) -> [Double] {
        guard let regex = try? Regex(Self.moneyPattern).ignoresCase() else { return [] }
        return line.matches(of: regex).compactMap { match in
            let token = String(line[match.range])
            let hasCurrency = token.range(of: #"[€$£]|RON|lei|EUR"#, options: [.regularExpression, .caseInsensitive]) != nil
            let hasDecimals = token.range(of: #"[.,]\d{2}\s*\D*$"#, options: .regularExpression) != nil
            guard hasCurrency || hasDecimals else { return nil }
            return amount(in: token.replacingOccurrences(of: "\u{00A0}", with: "").replacingOccurrences(of: " ", with: ""))
        }
    }

    // MARK: - Keyword extraction

    private enum Field { case total, fares, tips, bonus, trips }

    /// Checked in order, so "Trip earnings" is fares (not trips) and "Tips" never counts as the total.
    private static let keywords: [(Field, [String])] = [
        (.fares, ["trip earnings", "câștiguri din curse", "castiguri din curse", "gains des courses", "montant des courses",
                    "fare", "fares", "tarif", "tarife"]),
        (.tips, ["tip", "tips", "bacsis", "bacșiș", "bacșișuri", "bacsisuri", "pourboire", "pourboires"]),
        (.bonus, ["promotion", "promotions", "promoții", "promotii", "bonus", "boost", "quest", "incentive", "stimulent", "prime", "primes"]),
        (.trips, ["trips", "trip", "curse", "cursă", "cursa", "călătorii", "calatorii", "rides", "courses", "course"]),
        (.total, ["total", "earnings", "câștiguri", "castiguri", "you earned", "ai câștigat", "payout", "net", "gains", "revenus"]),
    ]

    /// Lines that show money that is not the driver's: what the passenger paid, the platform's cut,
    /// cash already collected, balances, and non-money numbers (points, distance, time).
    private static let ignoredWords: Set<String> = [
        "gross", "brut", "brute", "customer", "client", "clientul", "price", "pret", "commission", "comision",
        "fee", "fees", "taxa", "cash", "numerar", "balance", "sold", "points", "puncte", "distance", "distanta",
        "duration", "durata", "online", "especes", "espèces", "frais", "solde", "prix", "duree", "durée", "ligne",
    ]

    /// Words marking the amount after the platform's commission; preferred over any other total.
    private static let netWords: Set<String> = ["net", "nete", "neto", "your", "tale"]

    func parse(lines: [String], now: Date = .now) -> ScreenshotEarnings {
        var result = ScreenshotEarnings(source: .textMatching, recognizedLines: lines)
        let all = fold(lines.joined(separator: "\n"))

        if all.contains("uber") { result.platform = .uber }
        else if all.contains("bolt") { result.platform = .bolt }
        else if all.contains("freenow") || all.contains("free now") { result.platform = .freeNow }
        result.scope = scope(of: all)

        let kept = lines.filter { words(in: fold($0)).isDisjoint(with: Self.ignoredWords) }
        var totalIsNet = false
        for (index, line) in kept.enumerated() {
            let folded = fold(line)
            guard let kind = field(for: folded) else { continue }
            if kind == .trips {
                if result.trips == nil, let count = firstInteger(in: line) { result.trips = count }
                continue
            }
            // The amount is on the same row, or alone on the next row (stacked layouts).
            var values = amounts(in: line)
            if values.isEmpty, index + 1 < kept.count, field(for: fold(kept[index + 1])) == nil {
                values = amounts(in: kept[index + 1])
            }
            guard let value = values.last, value > 0 else { continue }
            switch kind {
            case .total:
                if !words(in: folded).isDisjoint(with: Self.netWords) {
                    result.total = totalIsNet ? result.total : value
                    totalIsNet = true
                } else if !totalIsNet {
                    result.total = max(result.total ?? 0, value)
                }
            case .fares: if result.fares == nil { result.fares = value }
            case .tips: if result.tips == nil { result.tips = value }
            case .bonus: result.bonus = (result.bonus ?? 0) + value
            case .trips: break
            }
        }

        // Headline amount with no label (big number at the top): the largest of the driver's amounts.
        if result.total == nil {
            result.total = kept.flatMap { amounts(in: $0) }.filter { $0 > 0 }.max()
        }
        if result.scope == .trip, result.trips == nil { result.trips = 1 }
        result.distanceKm = distance(in: lines)
        result.cashCollected = cash(in: lines)
        if result.scope == .trip { result.destination = destination(in: lines) }
        return result.normalized()
    }

    // MARK: - Cash

    private static let cashWords: Set<String> = ["cash", "numerar"]
    /// "Cash out" is Uber's instant payout and "balance"/"sold" is what's owed, not cash from passengers.
    private static let notCashWords: Set<String> = ["out", "balance", "sold", "payout", "withdraw", "retragere", "retras"]

    /// "Cash collected  145,00 lei" or "Numerar încasat  -145,00 lei": money already in the driver's pocket.
    func cash(in lines: [String]) -> Double? {
        for (index, line) in lines.enumerated() {
            let words = words(in: fold(line))
            guard !words.isDisjoint(with: Self.cashWords), words.isDisjoint(with: Self.notCashWords) else { continue }
            var values = amounts(in: line)
            if values.isEmpty, index + 1 < lines.count, field(for: fold(lines[index + 1])) == nil {
                values = amounts(in: lines[index + 1])
            }
            if let value = values.last, value != 0 { return abs(value) }
        }
        return nil
    }

    // MARK: - Distance and destination

    /// Already folded (lowercase, no diacritics).
    private static let distanceWords: Set<String> = ["distance", "distanta", "parcursa", "parcurs"]

    /// "Distance  9.4 km" or "Distanță parcursă  412,5 km". A labelled row wins over a stray "km"
    /// elsewhere (like "3 km away" in a promotion).
    func distance(in lines: [String]) -> Double? {
        let values = lines.compactMap { line -> (Double, Bool)? in
            guard let match = line.firstMatch(of: /(\d+(?:[.,]\d{1,2})?)\s?km\b/.ignoresCase()), let km = amount(in: String(match.1)) else { return nil }
            return (km, !words(in: fold(line)).isDisjoint(with: Self.distanceWords))
        }
        return (values.first { $0.1 } ?? values.first)?.0
    }

    /// Labels before the drop-off address on Uber and Bolt trip screens.
    private static let dropOffLabels = ["drop-off", "dropoff", "drop off", "destination", "destinatie", "destinatia", "to:"]
    private static let pickUpLabels = ["pick-up", "pickup", "pick up", "preluare", "from:"]
    /// Words that make a line look like a street address.
    private static let streetWords: Set<String> = [
        "str", "strada", "bd", "bdul", "bulevardul", "calea", "sos", "soseaua", "piata", "aleea", "splaiul", "intrarea",
        "street", "st", "avenue", "ave", "road", "rd", "boulevard", "blvd", "square", "airport", "aeroportul",
    ]

    /// The drop-off address: the row after a "Drop-off"/"Destinație" label (or the text after it), otherwise
    /// the last address-looking row, since trip screens list pickup first and drop-off second.
    func destination(in lines: [String]) -> String? {
        for (index, line) in lines.enumerated() {
            let folded = fold(line)
            guard let label = Self.dropOffLabels.first(where: { folded.hasPrefix($0) }) else { continue }
            let rest = cleanAddress(String(line.dropFirst(label.count)))
            if !rest.isEmpty { return rest }
            if index + 1 < lines.count { return cleanAddress(lines[index + 1]) }
        }
        let addresses = lines.filter { line in
            let folded = fold(line)
            return Self.pickUpLabels.allSatisfy { !folded.hasPrefix($0) }
                && !words(in: folded).isDisjoint(with: Self.streetWords)
                && amounts(in: line).isEmpty
        }
        return addresses.last.map(cleanAddress)
    }

    /// Drops a leading time ("10:58 AM", "22:14") and separators left by the label.
    private func cleanAddress(_ text: String) -> String {
        text.replacing(/^\s*\d{1,2}:\d{2}\s*(?:AM|PM|am|pm)?/, with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " :·-–\t"))
    }

    private func scope(of folded: String) -> ScreenshotEarnings.Scope {
        if folded.contains("trip details") || folded.contains("detalii cursa") || folded.contains("ride details") { return .trip }
        if folded.contains("week") || folded.contains("saptaman") { return .week }
        // A date range such as "6 oct. - 12 oct." or "Oct 5 - Oct 11" is a weekly (or longer) summary.
        if folded.contains(/\d{1,2}\s*[a-z]{3,4}\.?\s*[-–]\s*\d{1,2}\s*[a-z]{3,4}/)
            || folded.contains(/[a-z]{3,4}\.?\s*\d{1,2}\s*[-–]\s*[a-z]{3,4}\.?\s*\d{1,2}/) {
            return .week
        }
        if folded.contains("today") || folded.contains("astazi") || words(in: folded).contains("azi") { return .day }
        return .unknown
    }

    private func words(in foldedLine: String) -> Set<String> {
        Set(foldedLine.split { !$0.isLetter }.map(String.init))
    }

    /// Lowercased without diacritics: OCR returns Romanian "ș" either with a comma (U+0219) or a
    /// cedilla (U+015F), and sometimes drops it entirely.
    private func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    private func field(for foldedLine: String) -> Field? {
        let words = words(in: foldedLine)
        for (field, keys) in Self.keywords {
            for key in keys.map(fold) where key.contains(" ") ? foldedLine.contains(key) : words.contains(key) {
                return field
            }
        }
        return nil
    }

    private func firstInteger(in line: String) -> Int? {
        line.firstMatch(of: /\b(\d{1,3})\b/).flatMap { Int($0.1) }
    }
}
