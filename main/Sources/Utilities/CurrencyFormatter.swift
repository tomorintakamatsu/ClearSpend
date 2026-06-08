import Foundation

enum CurrencyFormat {
    nonisolated(unsafe) static var language = "en"

    private static let zeroDecimalCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "ISK", "JPY", "KMF", "KRW",
        "MGA", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF"
    ]

    private static let supportedCurrencySymbols: [String: String] = [
        "USD": "$",
        "EUR": "€",
        "GBP": "£",
        "JPY": "¥",
        "CAD": "C$",
        "AUD": "A$",
        "CHF": "CHF",
        "CNY": "¥",
        "HKD": "HK$",
        "SGD": "S$",
        "KRW": "₩",
        "BRL": "R$"
    ]

    static func format(_ amount: Double, currency: String = "USD") -> String {
        formatted(amount, currency: currency)
    }

    static func formatSigned(_ amount: Double, currency: String = "USD") -> String {
        let roundedAmount = rounded(amount, fractionDigits: fractionDigits(for: currency))
        let prefix = roundedAmount >= 0 ? "+" : "−"
        return prefix + format(abs(roundedAmount), currency: currency)
    }

    static func currencySymbol(for currency: String = "USD") -> String {
        if let supported = supportedSymbol(for: currency) {
            return supported
        }
        let formatter = makeFormatter(currency: currency, fractionDigits: fractionDigits(for: currency))
        formatter.currencyCode = currency
        return formatter.currencySymbol ?? "$"
    }

    static func supportedSymbol(for currency: String) -> String? {
        supportedCurrencySymbols[currency.uppercased()]
    }

    static func formatForeign(_ amount: Double, currency: String) -> String {
        formatted(amount, currency: currency)
    }

    static func formatForeignSigned(_ amount: Double, currency: String) -> String {
        let roundedAmount = rounded(amount, fractionDigits: fractionDigits(for: currency))
        let prefix = roundedAmount >= 0 ? "+" : "−"
        return prefix + formatForeign(abs(roundedAmount), currency: currency)
    }

    static func parseInput(_ value: String) -> Double? {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitMap = [
            "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
            "５": "5", "６": "6", "７": "7", "８": "8", "９": "9"
        ]
        digitMap.forEach { cleaned = cleaned.replacingOccurrences(of: $0.key, with: $0.value) }

        cleaned = cleaned
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "．", with: ".")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "｡", with: ".")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "\u{00a0}", with: "")

        cleaned = normalizeSeparators(cleaned)

        cleaned = cleaned.filter { $0.isNumber || $0 == "." || $0 == "-" }
        let decimalCount = cleaned.filter { $0 == "." }.count
        if decimalCount > 1 {
            let parts = cleaned.split(separator: ".", omittingEmptySubsequences: false)
            cleaned = parts.dropLast().joined() + "." + (parts.last.map(String.init) ?? "")
        }

        return Double(cleaned)
    }

    private static func normalizeSeparators(_ value: String) -> String {
        let commaCount = value.filter { $0 == "," }.count
        let dotCount = value.filter { $0 == "." }.count

        if commaCount > 0, dotCount > 0 {
            let lastComma = value.lastIndex(of: ",")!
            let lastDot = value.lastIndex(of: ".")!
            if lastComma > lastDot {
                return value
                    .replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: ".")
            }
            return value.replacingOccurrences(of: ",", with: "")
        }

        if commaCount > 0 {
            let parts = value.split(separator: ",", omittingEmptySubsequences: false)
            let looksLikeThousands = parts.count > 1 &&
                parts.dropFirst().allSatisfy { $0.count == 3 && $0.allSatisfy(\.isNumber) } &&
                (parts.first?.allSatisfy { $0.isNumber || $0 == "-" } ?? false)
            if looksLikeThousands {
                return value.replacingOccurrences(of: ",", with: "")
            }
            return value.replacingOccurrences(of: ",", with: ".")
        }

        return value
    }

    private static func formatted(_ amount: Double, currency: String) -> String {
        let fractionDigits = fractionDigits(for: currency)
        let roundedAmount = rounded(amount, fractionDigits: fractionDigits)
        let visibleDigits = visibleFractionDigits(for: roundedAmount, maxDigits: fractionDigits)
        let formatter = makeFormatter(currency: currency, fractionDigits: visibleDigits)

        return formatter.string(from: NSNumber(value: roundedAmount)) ?? "\(currency) \(roundedAmount)"
    }

    private static func makeFormatter(currency: String, fractionDigits: Int) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return formatter
    }

    private static func fractionDigits(for currency: String) -> Int {
        zeroDecimalCurrencies.contains(currency.uppercased()) ? 0 : 2
    }

    private static func visibleFractionDigits(for amount: Double, maxDigits: Int) -> Int {
        guard maxDigits > 0 else { return 0 }
        return amount.isWholeCurrencyValue ? 0 : maxDigits
    }

    private static func rounded(_ amount: Double, fractionDigits: Int) -> Double {
        guard fractionDigits > 0 else { return amount.rounded() }
        let scale = pow(10.0, Double(fractionDigits))
        return (amount * scale).rounded() / scale
    }

    private static var locale: Locale {
        switch language {
        case "ja": Locale(identifier: "ja_JP")
        case "zh": Locale(identifier: "zh_Hans")
        default: Locale(identifier: "en_US")
        }
    }
}

private extension Double {
    var isWholeCurrencyValue: Bool {
        abs(self.rounded() - self) < 0.000_000_1
    }
}
