import SwiftUI

struct RecentActivityList: View {
    @Environment(AppViewModel.self) private var viewModel
    let transactions: [Transaction]
    let currency: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    Haptics.selection()
                    withAnimation(AnimationPresets.fold) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        PennyLetIconTile(symbol: "clock.arrow.circlepath", tint: viewModel.primaryColor, size: 30, symbolScale: 0.43, shape: .capsule)
                        Text(viewModel.loc("Recent Activity"))
                            .font(.headline.weight(.semibold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .zIndex(1)

                Spacer()

                if isExpanded {
                    viewAllButton
                        .padding(.trailing, 56)
                        .transition(
                            .opacity
                                .combined(with: .move(edge: .trailing))
                                .combined(with: .scale(scale: 0.96, anchor: .trailing))
                        )
                }
            }

            if isExpanded {
                Group {
                    if transactions.isEmpty {
                        VStack(spacing: 10) {
                            PennyLetIconTile(symbol: "sparkles", tint: Color(.systemPurple), size: 42, shape: .circle)
                            Text(viewModel.loc("No transactions yet"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                    } else {
                        recentRows
                    }
                }
                .transition(.underHeaderReveal)
                .clipped()
                .zIndex(0)
            }
        }
        .padding(18)
        .premiumPanel(tint: viewModel.primaryColor)
        .animation(AnimationPresets.fold, value: isExpanded)
    }

    private var viewAllButton: some View {
        Button {
            Haptics.selection()
            viewModel.navigateToTab = 1
        } label: {
            HStack(spacing: 4) {
                Text(viewModel.loc("View All"))
                Image(systemName: "chevron.right")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(viewModel.primaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(viewModel.primaryColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var recentRows: some View {
        VStack(spacing: 4) {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, tx in
                TransactionRow(transaction: tx, currency: currency, isEmbedded: true)
                if index < transactions.count - 1 {
                    Divider()
                }
            }
        }
    }
}
