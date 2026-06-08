import Foundation

enum MoneyLogicV2CSVColumn: String, Codable, CaseIterable, Sendable {
    case date
    case postedDate = "posted_date"
    case description
    case merchant
    case amount
    case debit
    case credit
    case category
    case account
    case notes
    case type
}

struct MoneyLogicV2CSVColumnMapping: Codable, Equatable, Sendable {
    var date: String
    var postedDate: String?
    var description: String?
    var merchant: String?
    var amount: String?
    var debit: String?
    var credit: String?
    var category: String?
    var account: String?
    var notes: String?
    var type: String?
}

struct MoneyLogicV2ImportDuplicate: Identifiable, Equatable, Sendable {
    var id: String { existingTransactionId }
    var existingTransactionId: String
    var reason: String
}

struct MoneyLogicV2CSVImportPreviewRow: Identifiable, Equatable, Sendable {
    var id: String
    var transaction: MoneyLogicV2Transaction?
    var rawRow: [String: String]
    var lineNumber: Int
    var duplicate: MoneyLogicV2ImportDuplicate?
    var error: String?
}

struct MoneyLogicV2CSVImportPreview: Equatable, Sendable {
    var importBatchId: String
    var rows: [MoneyLogicV2CSVImportPreviewRow]

    var importableTransactions: [MoneyLogicV2Transaction] {
        rows.compactMap { row in
            guard row.error == nil, row.duplicate == nil else { return nil }
            return row.transaction
        }
    }

    var duplicateCount: Int {
        rows.filter { $0.duplicate != nil }.count
    }
}

enum MoneyLogicV2CSVImport {
    static func autoMapping(for headers: [String]) -> MoneyLogicV2CSVColumnMapping? {
        func header(_ candidates: [String]) -> String? {
            headers.first { original in
                let normalized = normalizeHeader(original)
                return candidates.contains(normalized)
            }
        }

        guard let date = header(["date", "transactiondate", "transdate", "posteddate", "postingdate"]) else {
            return nil
        }

        return MoneyLogicV2CSVColumnMapping(
            date: date,
            postedDate: header(["posteddate", "postingdate", "postdate"]),
            description: header(["description", "memo", "details", "name"]),
            merchant: header(["merchant", "payee", "vendor"]),
            amount: header(["amount", "transactionamount"]),
            debit: header(["debit", "withdrawal", "withdrawals", "spent"]),
            credit: header(["credit", "deposit", "deposits", "received"]),
            category: header(["category", "classification"]),
            account: header(["account", "accountname"]),
            notes: header(["notes", "note"]),
            type: header(["type", "transactiontype"])
        )
    }

    static func preview(
        csvText: String,
        mapping suppliedMapping: MoneyLogicV2CSVColumnMapping? = nil,
        defaultAccountId: String,
        defaultCurrency: String,
        existingTransactions: [MoneyLogicV2Transaction],
        importBatchId: String = UUID().uuidString
    ) -> MoneyLogicV2CSVImportPreview {
        let parsed = parse(csvText)
        guard let headers = parsed.first else {
            return MoneyLogicV2CSVImportPreview(importBatchId: importBatchId, rows: [])
        }

        let mapping = suppliedMapping ?? autoMapping(for: headers)
        let dataRows = parsed.dropFirst()
        var rows: [MoneyLogicV2CSVImportPreviewRow] = []

        for (offset, columns) in dataRows.enumerated() {
            let lineNumber = offset + 2
            let raw = Dictionary(uniqueKeysWithValues: headers.enumerated().map { index, header in
                (header, index < columns.count ? columns[index] : "")
            })

            guard let mapping else {
                rows.append(row(id: importBatchId, lineNumber: lineNumber, raw: raw, error: "No date column found"))
                continue
            }

            let parsedTransaction = transaction(
                from: raw,
                mapping: mapping,
                defaultAccountId: defaultAccountId,
                defaultCurrency: defaultCurrency,
                importBatchId: importBatchId
            )

            switch parsedTransaction {
            case .success(let transaction):
                let duplicate = likelyDuplicate(for: transaction, existingTransactions: existingTransactions)
                rows.append(
                    MoneyLogicV2CSVImportPreviewRow(
                        id: "\(importBatchId)-\(lineNumber)",
                        transaction: transaction,
                        rawRow: raw,
                        lineNumber: lineNumber,
                        duplicate: duplicate,
                        error: nil
                    )
                )
            case .failure(let error):
                rows.append(row(id: importBatchId, lineNumber: lineNumber, raw: raw, error: error.localizedDescription))
            }
        }

        return MoneyLogicV2CSVImportPreview(importBatchId: importBatchId, rows: rows)
    }

    static func undoImportBatch(
        transactions: [MoneyLogicV2Transaction],
        importBatchId: String
    ) -> [MoneyLogicV2Transaction] {
        transactions.filter { $0.importBatchId != importBatchId }
    }

    static func likelyDuplicate(
        for candidate: MoneyLogicV2Transaction,
        existingTransactions: [MoneyLogicV2Transaction],
        calendar: Calendar = .current
    ) -> MoneyLogicV2ImportDuplicate? {
        for existing in existingTransactions {
            guard existing.accountId == candidate.accountId else { continue }
            guard abs(existing.absoluteAmount - candidate.absoluteAmount) < 0.01 else { continue }
            guard abs(calendar.dateComponents([.day], from: calendar.startOfDay(for: existing.date), to: calendar.startOfDay(for: candidate.date)).day ?? 0) <= 1 else { continue }
            let existingText = MoneyLogicV2Text.similarityKey(existing.merchantRaw, existing.description)
            let candidateText = MoneyLogicV2Text.similarityKey(candidate.merchantRaw, candidate.description)
            guard !existingText.isEmpty, existingText == candidateText else { continue }
            return MoneyLogicV2ImportDuplicate(
                existingTransactionId: existing.id,
                reason: "Same account, nearby date, amount, and merchant"
            )
        }
        return nil
    }

    static func parse(_ csvText: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = csvText.makeIterator()

        while let character = iterator.next() {
            switch character {
            case "\"":
                if inQuotes {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    inQuotes = true
                }
            case "," where !inQuotes:
                row.append(field)
                field = ""
            case "\n" where !inQuotes:
                row.append(field)
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row)
                }
                row = []
                field = ""
            case "\r" where !inQuotes:
                continue
            default:
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(row)
            }
        }

        return rows
    }

    private static func transaction(
        from raw: [String: String],
        mapping: MoneyLogicV2CSVColumnMapping,
        defaultAccountId: String,
        defaultCurrency: String,
        importBatchId: String
    ) -> Result<MoneyLogicV2Transaction, ImportError> {
        guard let date = parseDate(raw[mapping.date]) else {
            return .failure(.invalidDate)
        }

        let postedDate = mapping.postedDate.flatMap { parseDate(raw[$0]) }
        guard let signedAmount = amount(from: raw, mapping: mapping), abs(signedAmount) > 0 else {
            return .failure(.invalidAmount)
        }

        let merchant = mapping.merchant.flatMap { cleaned(raw[$0]) }
        let description = mapping.description.flatMap { cleaned(raw[$0]) }
        let category = mapping.category.flatMap { cleaned(raw[$0]) }
        let accountId = mapping.account
            .flatMap { cleaned(raw[$0]) }
            .map { MoneyLogicV2Text.normalizedMerchant($0).replacingOccurrences(of: " ", with: "_") }
            ?? defaultAccountId
        let explicitType = mapping.type.flatMap { cleaned(raw[$0])?.lowercased() }
        let type: MoneyLogicV2TransactionType = {
            if explicitType?.contains("transfer") == true { return .transfer }
            if explicitType?.contains("refund") == true { return .refund }
            if explicitType?.contains("reimburse") == true { return .reimbursement }
            if explicitType?.contains("income") == true { return .income }
            if explicitType?.contains("expense") == true { return .expense }
            if signedAmount >= 0 { return .income }
            return .expense
        }()
        let bucket: MoneyLogicV2BucketType = {
            switch type {
            case .income:
                return .income
            case .transfer:
                return .transfer
            case .refund, .reimbursement:
                let detected = bucketType(for: category)
                return (detected == .transfer || detected == .excluded) ? .flexible : detected
            case .expense:
                return bucketType(for: category)
            case .adjustment:
                return .excluded
            }
        }()
        let now = Date()

        return .success(
            MoneyLogicV2Transaction(
                id: "csv-\(importBatchId)-\(UUID().uuidString)",
                accountId: accountId,
                date: date,
                postedDate: postedDate,
                amount: signedAmount,
                currency: defaultCurrency,
                merchantRaw: merchant,
                merchantNormalized: merchant.map(MoneyLogicV2Text.normalizedMerchant),
                description: description,
                type: type,
                categoryId: category.map(canonicalCategoryID),
                bucketType: bucket,
                tags: [],
                notes: mapping.notes.flatMap { cleaned(raw[$0]) },
                source: .csvImport,
                importBatchId: importBatchId,
                recurringSeriesId: nil,
                linkedTransactionId: nil,
                transferGroupId: nil,
                refundOfTransactionId: nil,
                isReviewed: false,
                isExcludedFromBudget: bucket == .transfer || bucket == .excluded,
                isExcludedFromReports: false,
                categorizationConfidence: category == nil ? .unknown : .medium,
                createdAt: now,
                updatedAt: now
            )
        )
    }

    private static func row(id: String, lineNumber: Int, raw: [String: String], error: String) -> MoneyLogicV2CSVImportPreviewRow {
        MoneyLogicV2CSVImportPreviewRow(
            id: "\(id)-\(lineNumber)",
            transaction: nil,
            rawRow: raw,
            lineNumber: lineNumber,
            duplicate: nil,
            error: error
        )
    }

    private static func amount(from raw: [String: String], mapping: MoneyLogicV2CSVColumnMapping) -> Double? {
        if let amountColumn = mapping.amount, let amount = parseAmount(raw[amountColumn]) {
            return amount
        }

        let debit = mapping.debit.flatMap { parseAmount(raw[$0]) } ?? 0
        let credit = mapping.credit.flatMap { parseAmount(raw[$0]) } ?? 0
        if debit != 0 || credit != 0 {
            return credit - debit
        }
        return nil
    }

    private static func parseAmount(_ value: String?) -> Double? {
        guard var value = cleaned(value), !value.isEmpty else { return nil }
        var negative = false
        if value.hasPrefix("("), value.hasSuffix(")") {
            negative = true
            value.removeFirst()
            value.removeLast()
        }
        value = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "¥", with: "")
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "£", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(value) else { return nil }
        return negative ? -amount : amount
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value = cleaned(value), !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) {
            return date
        }
        let formats = [
            "yyyy-MM-dd",
            "MM/dd/yyyy",
            "M/d/yyyy",
            "dd/MM/yyyy",
            "d/M/yyyy",
            "yyyy/MM/dd",
            "MMM d, yyyy",
            "MMMM d, yyyy"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }
        return nil
    }

    private static func cleaned(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizeHeader(_ header: String) -> String {
        header
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "", options: .regularExpression)
    }

    private static func bucketType(for category: String?) -> MoneyLogicV2BucketType {
        let value = canonicalCategoryID(category ?? "").replacingOccurrences(of: "_", with: " ")
        if value.contains("rent") || value.contains("mortgage") || value.contains("utility") || value.contains("insurance") || value.contains("phone") || value.contains("internet") || value.contains("subscription") {
            return .fixed
        }
        if value.contains("debt") || value.contains("loan") || value.contains("credit card payment") {
            return .debt
        }
        if value.contains("travel") || value.contains("annual") || value.contains("tax") || value.contains("maintenance") || value.contains("medical") {
            return .nonMonthly
        }
        if value.contains("saving") || value.contains("goal") || value.contains("emergency") {
            return .goal
        }
        if value.contains("transfer") || value.contains("payment") || value.contains("ignore") {
            return .transfer
        }
        return .flexible
    }

    private static func canonicalCategoryID(_ value: String) -> String {
        let normalized = MoneyLogicV2Text.normalizedMerchant(value)
            .replacingOccurrences(of: " ", with: "_")
        let aliases: [String: String] = [
            "rent_mortgage": "rent",
            "rent_housing": "rent",
            "housing": "rent",
            "fixed_spending": "fixed_spending",
            "fixed_expenses": "fixed_spending",
            "bills_utilities": "bills",
            "medical_bills": "medical",
            "minimum_debt_payment": "minimum_debt_payments",
            "minimum_debt_payments": "minimum_debt_payments",
            "credit_card_payment": "credit_card_payment",
            "card_payment": "credit_card_payment",
            "transport_fixed": "transportation_fixed",
            "transportation_fixed": "transportation_fixed",
            "annual_fee": "annual_fees",
            "annual_fees": "annual_fees",
            "home_maintenance": "home_maintenance",
            "emergency_buffer": "emergency_buffer",
            "emergency_fund": "emergency_fund",
            "big_purchase": "big_purchase",
            "debt_extra_payment": "debt_extra_payment",
            "side_income": "side_income",
            "payroll": "paycheck",
            "paycheck": "paycheck",
            "other_income": "other_income",
            "balance_adjustment": "balance_adjustment"
        ]
        if let alias = aliases[normalized] { return alias }
        if normalized.contains("refund") { return "refund" }
        if normalized.contains("reimbursement") || normalized.contains("reimburse") { return "reimbursement" }
        if normalized.contains("transfer") { return "transfer" }
        if normalized.contains("credit_card") || normalized.contains("card_payment") { return "credit_card_payment" }
        if normalized.contains("subscription") { return "subscriptions" }
        if normalized.contains("grocery") { return "groceries" }
        if normalized.contains("dining") || normalized.contains("restaurant") { return "dining" }
        if normalized.contains("coffee") { return "coffee" }
        if normalized.contains("medical") { return "medical" }
        return normalized.isEmpty ? "miscellaneous" : normalized
    }

    private enum ImportError: LocalizedError {
        case invalidDate
        case invalidAmount

        var errorDescription: String? {
            switch self {
            case .invalidDate:
                return "Invalid or missing date"
            case .invalidAmount:
                return "Invalid or missing amount"
            }
        }
    }
}
