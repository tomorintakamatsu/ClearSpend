import SwiftUI

struct SpendHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let summary: SpendSummary
    var startFromTodaySummary: StartFromTodaySummary?
    var localFirstSummary: MoneyLogicV2SafeToSpendSummary?
    let currency: String
    let theme: AppTheme
    var onEditSnapshot: (() -> Void)?

    private var tint: Color {
        viewModel.primaryColor
    }

    private var headlineAmount: Double {
        if let startFromTodaySummary {
            return startFromTodaySummary.trueSafeToSpend
        }
        return localFirstSummary?.trueSafeToSpend ?? summary.safeDaily
    }

    private var isOverBudget: Bool {
        if let startFromTodaySummary {
            return startFromTodaySummary.trueSafeToSpend < 0
        }
        return localFirstSummary.map { $0.trueSafeToSpend < 0 } ?? summary.isOverBudget
    }

    private var headlineTitle: String {
        if startFromTodaySummary != nil {
            return viewModel.loc("Safe Until Payday")
        }
        return viewModel.loc(localFirstSummary == nil ? "Safe to Spend Today" : "Safe to Spend")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headlineTitle)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(tint)
                    if let freshnessText {
                        Text(freshnessText)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }
                }

                Spacer()

                Text(isOverBudget ? viewModel.loc("Needs attention") : viewModel.loc("Ready"))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isOverBudget ? Color(.systemRed) : tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((isOverBudget ? Color(.systemRed) : tint).opacity(0.10), in: Capsule(style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(CurrencyFormat.format(headlineAmount, currency: currency))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .currencyAmountDisplay(minScale: 0.52)
                    .layoutPriority(1)

                if let startFromTodaySummary {
                    Text(viewModel.loc("Today's money − protected money − bills before payday."))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    paydayMetricRow(
                        dailyAmount: startFromTodaySummary.dailySafeToSpend,
                        daysLeft: startFromTodaySummary.daysUntilNextIncome
                    )

                    startFromTodayBreakdown(startFromTodaySummary)
                        .padding(.top, 8)
                } else if let localFirstSummary {
                    Text("\(viewModel.loc("Daily safe amount")): \(CurrencyFormat.format(localFirstSummary.dailySafeToSpend, currency: currency))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(viewModel.loc("After upcoming bills, goals, and planned set-asides."))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(26)
        .premiumPanel(tint: tint)
    }

    private var freshnessText: String? {
        guard let updatedDate = snapshotUpdatedDate else {
            return viewModel.loc("Update your balance when money changes.")
        }
        if Calendar.current.isDateInToday(updatedDate) {
            return viewModel.loc("Updated today")
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(viewModel.loc("Updated")) \(formatter.string(from: updatedDate))"
    }

    private var snapshotUpdatedDate: Date? {
        guard let budget = viewModel.currentBudget else { return nil }
        return budget.updatedDate.flatMap(AppViewModel.dateFromStoredString)
            ?? budget.createdDate.flatMap(AppViewModel.dateFromStoredString)
            ?? budget.startDate.flatMap(AppViewModel.dateFromStoredString)
    }

    private func paydayMetricRow(dailyAmount: Double, daysLeft: Int) -> some View {
        HStack(spacing: 10) {
            metricPill(
                title: viewModel.loc("Daily until payday"),
                value: CurrencyFormat.format(dailyAmount, currency: currency),
                icon: "sun.max.fill"
            )
            metricPill(
                title: viewModel.loc("Days left"),
                value: "\(max(0, daysLeft))",
                icon: "calendar"
            )
        }
    }

    private func metricPill(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(value)
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func startFromTodayBreakdown(_ summary: StartFromTodaySummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Label(viewModel.loc("Why this number?"), systemImage: "list.bullet.clipboard")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Spacer()

                if let onEditSnapshot {
                    Button {
                        Haptics.selection()
                        onEditSnapshot()
                    } label: {
                        Text(viewModel.loc("Update"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(tint.opacity(0.10), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(spacing: 7) {
                moneyRow(viewModel.loc("Money counted today"), amount: summary.currentMoney, sign: .positive)
                moneyRow(viewModel.loc("Bills still due"), amount: summary.billsDueBeforeNextIncome, sign: .negative)
                if summary.subscriptionCommitmentsBeforeNextIncome > 0 {
                    moneyRow(viewModel.loc("Subscriptions before payday"), amount: summary.subscriptionCommitmentsBeforeNextIncome, sign: .negative)
                }
                moneyRow(viewModel.loc("Savings to hold"), amount: summary.savingsDueBeforeNextIncome, sign: .negative)
                moneyRow(viewModel.loc("Protected money"), amount: summary.moneyToKeepUntouched, sign: .negative)
                Divider().opacity(0.5)
                moneyRow(viewModel.loc("Safe until payday"), amount: summary.trueSafeToSpend, sign: .plain, isTotal: true)
                if summary.nextIncomeAmount > 0 {
                    Divider().opacity(0.35)
                    contextRow(
                        viewModel.loc("Next paycheck"),
                        amount: summary.nextIncomeAmount,
                        detail: viewModel.loc("Not counted until payday.")
                    )
                }
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.12), lineWidth: 1)
        }
    }

    private enum MoneyRowSign {
        case positive
        case negative
        case plain
    }

    private func moneyRow(_ title: String, amount: Double, sign: MoneyRowSign, isTotal: Bool = false) -> some View {
        let prefix: String = {
            switch sign {
            case .positive:
                return "+"
            case .negative:
                return "-"
            case .plain:
                return ""
            }
        }()

        let amountText = isTotal
            ? CurrencyFormat.format(amount, currency: currency)
            : "\(prefix)\(CurrencyFormat.format(abs(amount), currency: currency))"

        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(isTotal ? .caption.weight(.bold) : .caption)
                .foregroundStyle(isTotal ? .primary : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Spacer(minLength: 8)

            Text(amountText)
                .font(isTotal ? .subheadline.weight(.bold).monospacedDigit() : .caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(isTotal ? (amount < 0 ? Color(.systemRed) : tint) : .primary)
                .currencyAmountDisplay(minScale: 0.6)
        }
    }

    private func contextRow(_ title: String, amount: Double, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(CurrencyFormat.format(amount, currency: currency))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .currencyAmountDisplay(minScale: 0.6)
        }
    }

}
