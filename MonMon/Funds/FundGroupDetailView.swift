import SwiftData
import SwiftUI

/// Which fund's positions a pushed screen is showing. A route rather than the
/// group itself: the screen re-reads its positions from the store, so editing
/// one updates what is on screen instead of leaving a stale copy behind.
struct FundGroupRoute: Hashable {
    /// `nil` for positions whose instrument is missing from the catalogue.
    let instrumentID: UUID?
}

/// Every purchase of one fund, newest first, under the totals for the stack.
///
/// This is where dollar-cost averaging is read back: the group card says what
/// the position is worth in one line, and this says what each buy contributed.
struct FundGroupDetailView: View {
    let route: FundGroupRoute

    @Query(sort: \FundHolding.createdAt, order: .reverse)
    private var holdings: [FundHolding]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editorMode: FundEditorMode?

    /// Passed in rather than read from the clock, so a preview and a test both
    /// get a stable answer for whether the price is stale.
    var asOf: Date = .now

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    if positions.isEmpty {
                        emptyState
                    } else {
                        FundGroupCard(group: group, asOf: asOf)

                        positionsSection
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(group.symbol)
        .accessibilityIdentifier("fund-group-\(group.id)")
        .sheet(item: $editorMode) { mode in
            FundEditorView(
                mode: mode,
                kinds: group.instrument?.kind == .gold ? [.gold] : [.fund, .etf]
            )
        }
        .tint(MonMonTheme.accent)
    }

    private var positions: [FundHolding] {
        FundSummary.positions(forInstrumentID: route.instrumentID, holdings: holdings)
    }

    private var group: FundPositionGroup {
        FundPositionGroup(
            instrument: route.instrumentID.flatMap { id in
                instruments.first { $0.id == id }
            },
            instrumentID: route.instrumentID,
            holdings: positions
        )
    }

    private var positionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Positions")
                    .font(.title3.weight(.semibold))

                Text(positions.count.formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.funds)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.funds.opacity(0.16), in: Capsule())

                Spacer(minLength: 8)

                Button {
                    editorMode = .add
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MonMonTheme.onAccent)
                        .frame(width: 32, height: 32)
                        .background(MonMonTheme.accent, in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Holding")
                .accessibilityIdentifier("fund-group-add-position")
            }

            ForEach(positions) { holding in
                Button {
                    editorMode = .edit(holding)
                } label: {
                    FundHoldingCard(
                        holding: holding,
                        instrument: instruments.matching(holding),
                        sourceAccountName: accountName(for: holding),
                        asOf: asOf
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("fund-\(holding.id.uuidString)")
                .accessibilityHint("Opens this position for editing")
            }
        }
    }

    /// Reached only by deleting every position from the screen showing them, so
    /// it says what happened rather than offering a way in.
    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nothing held here anymore")
                .font(.title3.weight(.semibold))

            Text("Every position in this fund has been removed.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func accountName(for holding: FundHolding) -> String? {
        guard let sourceAccountID = holding.sourceAccountID else {
            return nil
        }

        return accounts.first { $0.id == sourceAccountID }?.name
    }
}
