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

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \CashAccount.createdAt, order: .forward)
    private var accounts: [CashAccount]

    @State private var editorMode: FundEditorMode?
    @State private var saleEditorMode: FundSaleEditorMode?
    @State private var expandedSaleLots: Set<UUID> = []

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
        .toolbar {
            if group.units > 0 {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close position", systemImage: "arrow.up.right.circle") {
                        saleEditorMode = .closeGroup(instrumentID: route.instrumentID)
                    }
                    .accessibilityIdentifier("fund-group-close-position")
                }
            }
        }
        .sheet(item: $editorMode) { mode in
            FundEditorView(
                mode: mode,
                kinds: group.instrument?.kind == .gold ? [.gold] : [.fund, .etf]
            )
        }
        .sheet(item: $saleEditorMode) { mode in
            FundSaleEditorView(mode: mode)
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
            holdings: positions,
            sales: FundSaleSummary.sales(of: positions, sales: sales)
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
                positionRow(holding)
            }
        }
    }

    /// A card with its actions beneath it rather than a card that is itself one
    /// button.
    ///
    /// A position now has three things to do to it — edit, sell, read its sales
    /// back — and a button inside a button swallows the inner tap in SwiftUI.
    /// Naming each action costs a row of the screen and removes the guesswork.
    private func positionRow(_ holding: FundHolding) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FundHoldingCard(
                holding: holding,
                instrument: instruments.matching(holding),
                sales: salesFor(holding),
                sourceAccountName: accountName(for: holding),
                asOf: asOf
            )

            HStack(spacing: 10) {
                Button("Edit", systemImage: "pencil") {
                    editorMode = .edit(holding)
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)
                .accessibilityIdentifier("fund-\(holding.id.uuidString)")

                if holding.remainingUnits(sales: sales) > 0 {
                    Button("Sell", systemImage: "arrow.up.right") {
                        saleEditorMode = .sell(holding)
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.funds)
                    .accessibilityIdentifier("fund-sell-\(holding.id.uuidString)")
                }

                Spacer(minLength: 8)

                if !salesFor(holding).isEmpty {
                    Button {
                        toggleSales(for: holding)
                    } label: {
                        Label(
                            "\(salesFor(holding).count) sales",
                            systemImage: expandedSaleLots.contains(holding.id)
                                ? "chevron.up" : "chevron.down"
                        )
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .accessibilityIdentifier("fund-sales-\(holding.id.uuidString)")
                }
            }
            .padding(.horizontal, 4)

            if expandedSaleLots.contains(holding.id) {
                ForEach(salesFor(holding)) { sale in
                    Button {
                        saleEditorMode = .edit(sale)
                    } label: {
                        FundSaleCard(
                            sale: sale,
                            costPerUnit: holding.averageCostPerUnit,
                            isGold: instruments.matching(holding)?.kind == .gold,
                            proceedsAccountName: accountName(forID: sale.proceedsAccountID)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .accessibilityIdentifier("fund-sale-\(sale.id.uuidString)")
                    .accessibilityHint("Opens this sale for editing")
                }
            }
        }
    }

    private func salesFor(_ holding: FundHolding) -> [FundSale] {
        FundSaleSummary.sales(for: holding, sales: sales)
    }

    private func toggleSales(for holding: FundHolding) {
        if expandedSaleLots.contains(holding.id) {
            expandedSaleLots.remove(holding.id)
        } else {
            expandedSaleLots.insert(holding.id)
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
        holding.sourceAccountID.flatMap(accountName(forID:))
    }

    private func accountName(forID id: UUID) -> String? {
        accounts.first { $0.id == id }?.name
    }
}
