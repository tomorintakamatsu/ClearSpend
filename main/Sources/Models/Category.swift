import Foundation
import SwiftUI

struct AppCategory: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let icon: String
    let color: Color

    static let expenseCategories: [AppCategory] = [
        .init(id: "food", label: "Food & Dining", icon: "fork.knife", color: .orange),
        .init(id: "groceries", label: "Groceries", icon: "basket.fill", color: .green),
        .init(id: "dining", label: "Dining", icon: "fork.knife.circle.fill", color: .orange),
        .init(id: "coffee", label: "Coffee", icon: "cup.and.saucer.fill", color: .brown),
        .init(id: "transport", label: "Transport", icon: "car.fill", color: .blue),
        .init(id: "transportation_fixed", label: "Transportation Fixed", icon: "car.circle.fill", color: .blue),
        .init(id: "shopping", label: "Shopping", icon: "bag.fill", color: .pink),
        .init(id: "entertainment", label: "Entertainment", icon: "tv.fill", color: .purple),
        .init(id: "health", label: "Health", icon: "heart.fill", color: .red),
        .init(id: "medical", label: "Medical", icon: "cross.case.fill", color: .red),
        .init(id: "bills", label: "Bills & Utilities", icon: "doc.text.fill", color: .yellow),
        .init(id: "fixed_spending", label: "Fixed Spending", icon: "calendar.badge.clock", color: .indigo),
        .init(id: "rent", label: "Rent / Housing", icon: "house.fill", color: .indigo),
        .init(id: "utilities", label: "Utilities", icon: "bolt.fill", color: .yellow),
        .init(id: "insurance", label: "Insurance", icon: "shield.fill", color: .teal),
        .init(id: "phone", label: "Phone", icon: "iphone", color: .blue),
        .init(id: "internet", label: "Internet", icon: "wifi", color: .cyan),
        .init(id: "subscriptions", label: "Subscriptions", icon: "repeat", color: .cyan),
        .init(id: "travel", label: "Travel", icon: "airplane", color: .teal),
        .init(id: "car_maintenance", label: "Car Maintenance", icon: "wrench.and.screwdriver.fill", color: .gray),
        .init(id: "annual_fees", label: "Annual Fees", icon: "calendar.badge.clock", color: .purple),
        .init(id: "taxes", label: "Taxes", icon: "doc.text.fill", color: .brown),
        .init(id: "home_maintenance", label: "Home Maintenance", icon: "hammer.fill", color: .brown),
        .init(id: "emergency_buffer", label: "Emergency Buffer", icon: "lifepreserver.fill", color: .teal),
        .init(id: "education", label: "Education", icon: "graduationcap.fill", color: .mint),
        .init(id: "gifts", label: "Gifts", icon: "gift.fill", color: .red),
        .init(id: "personal", label: "Personal", icon: "person.fill", color: .mint),
        .init(id: "minimum_debt_payments", label: "Minimum Debt Payments", icon: "creditcard.fill", color: .red),
        .init(id: "debt_extra_payment", label: "Debt Extra Payment", icon: "arrow.down.circle.fill", color: .red),
        .init(id: "emergency_fund", label: "Emergency Fund", icon: "lock.shield.fill", color: .green),
        .init(id: "vacation", label: "Vacation", icon: "sun.max.fill", color: .teal),
        .init(id: "big_purchase", label: "Big Purchase", icon: "shippingbox.fill", color: .brown),
        .init(id: "transfer", label: "Transfer", icon: "arrow.left.arrow.right", color: .gray),
        .init(id: "credit_card_payment", label: "Credit Card Payment", icon: "creditcard.fill", color: .gray),
        .init(id: "refund", label: "Refund", icon: "arrow.uturn.backward.circle.fill", color: .green),
        .init(id: "reimbursement", label: "Reimbursement", icon: "person.crop.circle.badge.plus", color: .green),
        .init(id: "balance_adjustment", label: "Balance Adjustment", icon: "slider.horizontal.3", color: .gray),
        .init(id: "ignore", label: "Ignore", icon: "eye.slash.fill", color: .gray),
        .init(id: "other", label: "Other", icon: "ellipsis.circle.fill", color: .gray),
    ]

    static let incomeCategories: [AppCategory] = [
        .init(id: "paycheck", label: "Paycheck", icon: "banknote.fill", color: .green),
        .init(id: "salary", label: "Salary", icon: "briefcase.fill", color: .green),
        .init(id: "side_income", label: "Side Income", icon: "laptopcomputer", color: .blue),
        .init(id: "freelance", label: "Freelance", icon: "laptopcomputer", color: .blue),
        .init(id: "investment", label: "Investment", icon: "chart.line.uptrend.xyaxis", color: .purple),
        .init(id: "gift_in", label: "Gift", icon: "gift.fill", color: .pink),
        .init(id: "other_income", label: "Other Income", icon: "plus.circle.fill", color: .gray),
        .init(id: "transfer", label: "Transfer", icon: "arrow.left.arrow.right", color: .gray),
        .init(id: "credit_card_payment", label: "Credit Card Payment", icon: "creditcard.fill", color: .gray),
        .init(id: "refund", label: "Refund", icon: "arrow.uturn.backward.circle.fill", color: .green),
        .init(id: "reimbursement", label: "Reimbursement", icon: "person.crop.circle.badge.plus", color: .green),
        .init(id: "balance_adjustment", label: "Balance Adjustment", icon: "slider.horizontal.3", color: .gray),
        .init(id: "other_in", label: "Other", icon: "ellipsis.circle.fill", color: .gray),
    ]

    static func category(for id: String?, type: Transaction.TransactionType) -> AppCategory {
        let list = type == .income ? incomeCategories : expenseCategories
        let normalizedID = normalizedCategoryID(for: id, type: type)
        if let match = list.first(where: { $0.id == normalizedID }) {
            return match
        }
        guard let raw = id?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return list.last!
        }
        return AppCategory(id: normalizedID ?? customCategoryID(for: raw), label: displayLabel(forUnknown: raw), icon: "tag.fill", color: .teal)
    }

    static func customCategoryID(for value: String) -> String {
        let normalized = normalize(value)
        guard !normalized.isEmpty else {
            return "custom_\(stableHexID(for: value))"
        }
        return normalized
    }

    static func normalizedCategoryID(for value: String?, type: Transaction.TransactionType) -> String? {
        guard let value else { return nil }
        let normalized = normalize(value)
        guard !normalized.isEmpty else {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : customCategoryID(for: trimmed)
        }

        let list = type == .income ? incomeCategories : expenseCategories
        if list.contains(where: { $0.id == normalized }) {
            return normalized
        }

        if let directLabel = list.first(where: { normalize($0.label) == normalized }) {
            return directLabel.id
        }

        let aliases: [String: String] = [
            "rent_mortgage": "rent",
            "rent_housing": "rent",
            "housing": "rent",
            "fixed_spending": "fixed_spending",
            "fixed_expenses": "fixed_spending",
            "fixed": "fixed_spending",
            "bills_utilities": "bills",
            "utility": "utilities",
            "utilities": "utilities",
            "medical_bills": "medical",
            "medical": "medical",
            "minimum_debt_payment": "minimum_debt_payments",
            "minimum_debt_payments": "minimum_debt_payments",
            "debt_minimums": "minimum_debt_payments",
            "debt_payment": "minimum_debt_payments",
            "credit_card_payment": "credit_card_payment",
            "card_payment": "credit_card_payment",
            "transport_fixed": "transportation_fixed",
            "transportation_fixed": "transportation_fixed",
            "car_maintenance": "car_maintenance",
            "annual_fee": "annual_fees",
            "annual_fees": "annual_fees",
            "home_maintenance": "home_maintenance",
            "emergency_buffer": "emergency_buffer",
            "emergency_fund": "emergency_fund",
            "big_purchase": "big_purchase",
            "debt_extra_payment": "debt_extra_payment",
            "side_income": "side_income",
            "side_income_freelance": "side_income",
            "payroll": "paycheck",
            "paycheck": "paycheck",
            "other_income": "other_income",
            "balance_adjustment": "balance_adjustment"
        ]

        if let alias = aliases[normalized] {
            return alias
        }

        if normalized.contains("refund") { return "refund" }
        if normalized.contains("reimbursement") || normalized.contains("reimburse") { return "reimbursement" }
        if normalized.contains("transfer") { return "transfer" }
        if normalized.contains("credit_card") || normalized.contains("card_payment") { return "credit_card_payment" }
        if normalized.contains("subscription") { return "subscriptions" }
        if normalized.contains("grocery") || normalized.contains("groceries") { return "groceries" }
        if normalized.contains("dining") || normalized.contains("restaurant") || normalized.contains("food") { return "dining" }
        if normalized.contains("coffee") { return "coffee" }
        if normalized.contains("medical") || normalized.contains("pharmacy") || normalized.contains("health") { return "health" }
        if normalized.contains("bill") { return "bills" }

        return normalized.isEmpty ? customCategoryID(for: value) : normalized
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9]+"#, with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }

    private static func displayLabel(forUnknown value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Other" }
        if trimmed.contains("_") && trimmed.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil {
            return trimmed
                .split(separator: "_")
                .map { $0.prefix(1).uppercased() + $0.dropFirst() }
                .joined(separator: " ")
        }
        return trimmed
    }

    private static func stableHexID(for value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}
