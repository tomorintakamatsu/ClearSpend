import SwiftUI

struct TransactionListView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var searchText = ""
    @State private var filter: FilterType = .all
    @State private var pendingDelete: Transaction?
    @State private var listOpacity = 0.0

    enum FilterType: String, CaseIterable { case all, income, expense }

    private func makeSnapshot() -> TransactionListSnapshot {
        var result = viewModel.transactions
        switch filter {
        case .income: result = result.filter { $0.type == .income }
        case .expense: result = result.filter { $0.type == .expense }
        case .all: break
        }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                ($0.merchant ?? "").localizedCaseInsensitiveContains(q) ||
                ($0.note ?? "").localizedCaseInsensitiveContains(q) ||
                ($0.category ?? "").localizedCaseInsensitiveContains(q)
            }
        }

        let totals = result.reduce(into: (total: 0.0, income: 0.0, expense: 0.0)) { partial, transaction in
            partial.total += transaction.signedAmount
            switch transaction.type {
            case .income:
                partial.income += transaction.amount
            case .expense:
                partial.expense += transaction.amount
            }
        }
        let grouped = Dictionary(grouping: result) { $0.date }
            .sorted { $0.key > $1.key }
        return TransactionListSnapshot(
            filteredCount: result.count,
            groupedByDate: grouped,
            total: totals.total,
            incomeTotal: totals.income,
            expenseTotal: totals.expense
        )
    }

    var body: some View {
        let snapshot = makeSnapshot()

        transactionList(snapshot: snapshot)
            .clearSpendScreenBackground(theme: viewModel.theme)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: filter)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searchText)
            .searchable(text: $searchText, prompt: viewModel.loc("Search transactions"))
            .navigationTitle(viewModel.loc("Activity"))
            .navigationBarTitleDisplayMode(.inline)
    }

    private func transactionList(snapshot: TransactionListSnapshot) -> some View {
        List {
            if viewModel.isBlockVisible(.activityFilter) {
                filterSection
            }
            if viewModel.isBlockVisible(.activitySummary) {
                summarySection(snapshot: snapshot)
            }
            transactionSections(snapshot: snapshot)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var filterSection: some View {
        Section {
            Picker(viewModel.loc("Filter"), selection: $filter) {
                ForEach(FilterType.allCases, id: \.self) { f in
                    Text(viewModel.loc(f.rawValue.capitalized)).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filter) { oldValue, newValue in
                if oldValue != newValue {
                    Haptics.selection()
                }
            }
            .padding(10)
            .themedMiniPanel(tint: viewModel.primaryColor, cornerRadius: 16, colorStrength: 0.7)
            .accessibilityLabel(viewModel.loc("Filter"))
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func summarySection(snapshot: TransactionListSnapshot) -> some View {
        Section {
            ActivitySummaryCard(
                count: snapshot.filteredCount,
                total: snapshot.total,
                incomeTotal: snapshot.incomeTotal,
                expenseTotal: snapshot.expenseTotal,
                currency: viewModel.currency,
                filterName: viewModel.loc(filter.rawValue.capitalized),
                filter: filter,
                showsSplitTotals: filter == .all
            )
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func transactionSections(snapshot: TransactionListSnapshot) -> some View {
        ForEach(Array(snapshot.groupedByDate.enumerated()), id: \.element.0) { _, group in
            let (date, items) = group
            Section {
                ForEach(Array(items.enumerated()), id: \.element.id) { itemIndex, tx in
                    TransactionRow(transaction: tx, currency: viewModel.currency)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .staggeredEntrance(index: itemIndex)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteTransaction(tx) }
                            } label: {
                                Label(viewModel.loc("Delete"), systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    Text(formattedDate(date))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    let total = items.reduce(0) { $0 + $1.signedAmount }
                    Text(CurrencyFormat.formatSigned(total, currency: viewModel.currency))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .currencyAmountDisplay(minScale: 0.6)
                }
                .padding(.horizontal, 4)
                .padding(.top, 8)
            }
        }
    }

    private func formattedDate(_ dateStr: String) -> String {
        guard let date = Date.fromDateString(dateStr) ?? Date.fromISOString(dateStr) else {
            return dateStr
        }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().locale(dateLocale))
    }

    private var dateLocale: Locale {
        switch viewModel.language {
        case "ja": return Locale(identifier: "ja_JP")
        case "zh": return Locale(identifier: "zh_Hans")
        default: return Locale(identifier: "en_US")
        }
    }
}

private struct TransactionListSnapshot {
    let filteredCount: Int
    let groupedByDate: [(String, [Transaction])]
    let total: Double
    let incomeTotal: Double
    let expenseTotal: Double
}

private struct ActivitySummaryCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let count: Int
    let total: Double
    let incomeTotal: Double
    let expenseTotal: Double
    let currency: String
    let filterName: String
    let filter: TransactionListView.FilterType
    let showsSplitTotals: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            summaryHeader
            summaryDetails
        }
        .padding(20)
        .premiumPanel(tint: viewModel.primaryColor)
    }

    private var transactionCountText: String {
        switch viewModel.language {
        case "ja":
            return "\(count)件の取引"
        case "zh":
            return "\(count)笔交易"
        default:
            return "\(count) \(count == 1 ? "transaction" : "transactions")"
        }
    }

    private var summaryHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            PennyLetIconTile(symbol: "list.bullet.rectangle.portrait.fill", tint: viewModel.primaryColor, size: 44, shape: .capsule, isProminent: true)
                .transaction { transaction in
                    transaction.animation = nil
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(filterName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: false, vertical: true)
                Text(transactionCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)
        }
    }

    private var summaryDetails: some View {
        VStack(spacing: 8) {
            if showsSplitTotals {
                summaryAmountRow(viewModel.loc("Income"), amount: incomeTotal, color: .green, icon: "arrow.down.left.circle.fill")
                summaryAmountRow(viewModel.loc("Expense"), amount: expenseTotal, color: .red, icon: "arrow.up.right.circle.fill")
            } else {
                summaryAmountRow(
                    filterName,
                    amount: abs(total),
                    color: filter == .income ? .green : .red,
                    icon: filter == .income ? "arrow.down.left.circle.fill" : "arrow.up.right.circle.fill"
                )
            }
        }
    }

    private func summaryAmountRow(_ title: String, amount: Double, color: Color, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.10), in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 12)

            Text(CurrencyFormat.format(amount, currency: currency))
                .font(.title3.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
                .currencyAmountDisplay(minScale: 0.56)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .themedMiniPanel(tint: color, cornerRadius: 14)
    }
}
