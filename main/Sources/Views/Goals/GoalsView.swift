import SwiftUI

struct GoalsView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var showAddSheet = false
    @State private var pendingDeleteGoal: Goal?

    var body: some View {
        List {
            if viewModel.isBlockVisible(.goalsOverview) {
                Section {
                    GoalsHeroCard(goals: viewModel.goals, currency: viewModel.currency)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .listRowBackground(Color.clear)
                }
            }

            if viewModel.goals.isEmpty {
                ContentUnavailableView(
                    viewModel.loc("No Goals Yet"),
                    systemImage: "target",
                    description: Text(viewModel.loc("Set savings goals to track your progress"))
                )
            } else {
                ForEach(Array(viewModel.goals.enumerated()), id: \.element.id) { index, goal in
                    GoalRow(goal: goal, currency: viewModel.currency, theme: viewModel.theme)
                        .staggeredEntrance(index: index)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteGoal = goal
                            } label: {
                                Label(viewModel.loc("Delete"), systemImage: "trash")
                            }
                        }
                }
            }
        }
        .listStyle(.plain)
        .clearSpendScreenBackground(theme: viewModel.theme)
        .navigationTitle(viewModel.loc("Goals"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(viewModel.theme.primaryColor)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddGoalView()
        }
        .confirmationDialog(
            viewModel.loc("Delete Goal?"),
            isPresented: Binding(
                get: { pendingDeleteGoal != nil },
                set: { if !$0 { pendingDeleteGoal = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(viewModel.loc("Delete"), role: .destructive) {
                guard let goal = pendingDeleteGoal else { return }
                pendingDeleteGoal = nil
                Task { await viewModel.deleteGoal(goal) }
            }
            Button(viewModel.cancelLabel, role: .cancel) {
                pendingDeleteGoal = nil
            }
        } message: {
            Text(viewModel.loc("This cannot be undone."))
        }
    }
}

private struct GoalsHeroCard: View {
    @Environment(AppViewModel.self) private var viewModel
    let goals: [Goal]
    let currency: String

    private var saved: Double {
        goals.reduce(0) { $0 + $1.currentAmount }
    }

    private var target: Double {
        goals.reduce(0) { $0 + $1.targetAmount }
    }

    var body: some View {
        HStack(spacing: 14) {
            PennyLetIconTile(symbol: "target", tint: Color(.systemIndigo), size: 44, shape: .circle, isProminent: true)

            VStack(alignment: .leading, spacing: 4) {
                Text(CurrencyFormat.format(saved, currency: currency))
                    .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .currencyAmountDisplay(minScale: 0.54)
                Text(viewModel.loc("Savings direction"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(goals.count)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(target > 0 ? viewModel.loc("active goals") : viewModel.loc("goals"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.theme.primaryColor)
    }
}

struct GoalRow: View {
    let goal: Goal
    let currency: String
    let theme: AppTheme
    @Environment(AppViewModel.self) private var viewModel
    @State private var showsControls = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                PennyLetIconTile(symbol: "flag.checkered", tint: Color(.systemIndigo), size: 32, symbolScale: 0.4, shape: .diamond)

                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(Int(goal.progress * 100))" + viewModel.loc("% complete"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(CurrencyFormat.format(goal.currentAmount, currency: currency))
                        .font(.headline.weight(.bold).monospacedDigit())
                        .currencyAmountDisplay(minScale: 0.54)
                    Text("/ \(CurrencyFormat.format(goal.targetAmount, currency: currency))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .currencyAmountDisplay(minScale: 0.54)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.primaryColor)
                        .frame(width: geo.size.width * CGFloat(goal.progress), height: 10)
                }
            }
            .frame(height: 10)

            Button {
                withAnimation(AnimationPresets.fold) {
                    showsControls.toggle()
                }
            } label: {
                HStack {
                    Label(viewModel.loc("Add money"), systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Image(systemName: showsControls ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(theme.primaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(theme.primaryColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            if showsControls {
                HStack(spacing: 8) {
                    quickAddButton(10)
                    quickAddButton(50)
                    quickAddButton(100)
                    quickAddButton(500)
                }
                .transition(.foldReveal)
            }
        }
        .padding(16)
        .premiumPanel(tint: theme.primaryColor)
        .animation(AnimationPresets.fold, value: showsControls)
    }

    private func quickAddButton(_ amount: Double) -> some View {
        Button {
            Task {
                await viewModel.updateGoalAmount(id: goal.id, newAmount: goal.currentAmount + amount)
            }
        } label: {
            Text("+\(CurrencyFormat.format(amount, currency: currency))")
                .font(.caption.weight(.semibold).monospacedDigit())
                .currencyAmountDisplay(minScale: 0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(GoalQuickAddButtonStyle(theme: theme))
    }
}

private struct GoalQuickAddButtonStyle: ButtonStyle {
    let theme: AppTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(configuration.isPressed ? .white : theme.primaryColor)
            .background(
                configuration.isPressed ? theme.primaryColor : theme.primaryColor.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.primaryColor.opacity(configuration.isPressed ? 0.0 : 0.16), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .shadow(color: configuration.isPressed ? theme.primaryColor.opacity(0.18) : .clear, radius: 10, y: 5)
            .animation(.spring(response: 0.22, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

struct AddGoalView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetAmount = ""
    @State private var currentAmount = ""
    @State private var frequency = "monthly"

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (CurrencyFormat.parseInput(targetAmount) ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(viewModel.loc("Goal Details")) {
                    TextField(viewModel.loc("Name"), text: $name)
                    TextField(viewModel.loc("Target Amount"), text: $targetAmount)
                        .keyboardType(.decimalPad)
                    TextField(viewModel.loc("Current Amount"), text: $currentAmount)
                        .keyboardType(.decimalPad)
                }
                Section(viewModel.loc("Frequency")) {
                    Picker(viewModel.loc("Frequency"), selection: $frequency) {
                        Text(viewModel.loc("Weekly")).tag("weekly")
                        Text(viewModel.loc("Biweekly")).tag("biweekly")
                        Text(viewModel.loc("Monthly")).tag("monthly")
                    }
                }
            }
            .navigationTitle(viewModel.loc("New Goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(viewModel.loc("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.loc("Save")) { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func save() {
        guard let target = CurrencyFormat.parseInput(targetAmount), target > 0 else { return }
        let data = GoalData(
            name: name.trimmingCharacters(in: .whitespaces),
            targetAmount: target,
            currentAmount: CurrencyFormat.parseInput(currentAmount) ?? 0,
            frequency: frequency
        )
        Task {
            await viewModel.addGoal(data)
            dismiss()
        }
    }
}
