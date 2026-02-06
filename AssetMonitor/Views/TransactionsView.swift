import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var filterType: TransactionType?
    @State private var filterAsset: Asset?
    @State private var dateRange: DateRange = .all
    @State private var transactionToEdit: Transaction?

    enum DateRange: String, CaseIterable {
        case all = "All Time"
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"

        var startDate: Date? {
            let calendar = Calendar.current
            let now = Date()
            switch self {
            case .all: return nil
            case .week: return calendar.date(byAdding: .day, value: -7, to: now)
            case .month: return calendar.date(byAdding: .month, value: -1, to: now)
            case .year: return calendar.date(byAdding: .year, value: -1, to: now)
            }
        }
    }

    /// Returns transactions grouped by their linked pairs, excluding cash transactions that are linked
    var filteredTransactions: [Transaction] {
        var transactions = databaseService.transactions

        // Filter by search (asset symbol)
        if !searchText.isEmpty {
            let matchingAssetIds = databaseService.assets
                .filter { $0.symbol.localizedCaseInsensitiveContains(searchText) }
                .map { $0.id }
            transactions = transactions.filter { matchingAssetIds.contains($0.assetId) }
        }

        // Filter by type
        if let type = filterType {
            transactions = transactions.filter { $0.type == type }
        }

        // Filter by asset
        if let asset = filterAsset {
            transactions = transactions.filter { $0.assetId == asset.id }
        }

        // Filter by date
        if let startDate = dateRange.startDate {
            transactions = transactions.filter { $0.date >= startDate }
        }

        // Exclude cash transactions that are linked to other transactions (they'll be shown as part of the grouped row)
        let linkedCashTxIds = Set(transactions.compactMap { tx -> UUID? in
            guard tx.linkedTransactionId != nil,
                  let asset = databaseService.getAsset(byId: tx.assetId),
                  asset.type != .cash else { return nil }
            return tx.linkedTransactionId
        })
        transactions = transactions.filter { !linkedCashTxIds.contains($0.id) }

        return transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search by symbol...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .frame(maxWidth: 200)

                // Filter by type
                Picker("Type", selection: $filterType) {
                    Text("All Types").tag(nil as TransactionType?)
                    ForEach(TransactionType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type as TransactionType?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)

                // Filter by asset
                Picker("Asset", selection: $filterAsset) {
                    Text("All Assets").tag(nil as Asset?)
                    ForEach(databaseService.assets) { asset in
                        Text(asset.symbol).tag(asset as Asset?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                // Date range
                Picker("Period", selection: $dateRange) {
                    ForEach(DateRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("Add Transaction", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Summary
            HStack(spacing: Theme.Spacing.xxl) {
                TransactionSummaryCard(
                    title: "Bought",
                    value: filteredTransactions.filter { $0.type == .buy }.reduce(0) { $0 + $1.totalAmount },
                    count: filteredTransactions.filter { $0.type == .buy }.count,
                    color: Theme.TransactionColors.buy
                )

                TransactionSummaryCard(
                    title: "Sold",
                    value: filteredTransactions.filter { $0.type == .sell }.reduce(0) { $0 + $1.totalAmount },
                    count: filteredTransactions.filter { $0.type == .sell }.count,
                    color: Theme.TransactionColors.sell
                )

                TransactionSummaryCard(
                    title: "Dividends",
                    value: filteredTransactions.filter { $0.type == .dividend || $0.type == .interest }.reduce(0) { $0 + $1.totalAmount },
                    count: filteredTransactions.filter { $0.type == .dividend || $0.type == .interest }.count,
                    color: Theme.TransactionColors.dividend
                )

                Spacer()
            }
            .padding()

            Divider()

            // Transaction List
            if filteredTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions",
                    systemImage: "arrow.left.arrow.right",
                    description: Text(searchText.isEmpty ? "Add your first transaction" : "No transactions match your filters")
                )
            } else {
                List {
                    ForEach(filteredTransactions) { transaction in
                        let asset = databaseService.getAsset(byId: transaction.assetId)
                        let linkedTx = transaction.linkedTransactionId.flatMap { id in
                            databaseService.transactions.first { $0.id == id }
                        }
                        let linkedAsset = linkedTx.flatMap { databaseService.getAsset(byId: $0.assetId) }

                        if linkedTx != nil && asset?.type != .cash {
                            GroupedTransactionRowView(
                                transaction: transaction,
                                asset: asset,
                                linkedTransaction: linkedTx,
                                linkedAsset: linkedAsset
                            )
                            .contextMenu {
                                Button("Edit") {
                                    transactionToEdit = transaction
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteTransaction(transaction)
                                }
                            }
                        } else {
                            TransactionRowView(
                                transaction: transaction,
                                asset: asset
                            )
                            .contextMenu {
                                Button("Edit") {
                                    transactionToEdit = transaction
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteTransaction(transaction)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionSheet(preselectedAsset: filterAsset)
        }
        .sheet(item: $transactionToEdit) { transaction in
            EditTransactionSheet(transaction: transaction)
        }
        .onAppear {
            // If coming from assets view with selected asset
            if let selected = viewModel.selectedAsset {
                filterAsset = selected
                viewModel.selectedAsset = nil
            }
        }
    }
}

// MARK: - Transaction Summary Card

struct TransactionSummaryCard: View {
    let title: String
    let value: Double
    let count: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text("\(count) transactions")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Transaction Row View

struct TransactionRowView: View {
    let transaction: Transaction
    let asset: Asset?

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(Theme.TransactionColors.color(for: transaction.type).opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: transaction.type.iconName)
                    .foregroundColor(Theme.TransactionColors.color(for: transaction.type))
                    .font(.system(size: 16))
            }

            // Asset info
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(transaction.type.displayName)
                        .font(.caption)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .frame(width: 58)
                        .background(Theme.TransactionColors.color(for: transaction.type).opacity(0.2))
                        .cornerRadius(Theme.CornerRadius.small)
                    Text(asset?.symbol ?? "Unknown")
                        .fontWeight(.semibold)
                }
                Text(transaction.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Details
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if transaction.type == .dividend || transaction.type == .interest {
                    Text(transaction.totalAmount, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                        .foregroundColor(Theme.TransactionColors.dividend)
                } else {
                    Text("\(transaction.shares, specifier: "%.4f") @ \(transaction.pricePerShare, format: .currency(code: "USD"))")
                        .font(.subheadline)
                    Text(transaction.totalAmount, format: .currency(code: "USD"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Notes indicator
            if transaction.notes != nil {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Plan indicator
            if transaction.linkedPlanId != nil {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Grouped Transaction Row View

struct GroupedTransactionRowView: View {
    let transaction: Transaction
    let asset: Asset?
    let linkedTransaction: Transaction?
    let linkedAsset: Asset?

    var body: some View {
        HStack(spacing: 0) {
            // Left side: Main transaction (BUY/SELL)
            HStack(spacing: Theme.Spacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.TransactionColors.color(for: transaction.type).opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: transaction.type.iconName)
                        .foregroundColor(Theme.TransactionColors.color(for: transaction.type))
                        .font(.system(size: 16))
                }

                // Asset info with tag
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(transaction.type.displayName)
                            .font(.caption)
                            .padding(.vertical, Theme.Spacing.xxs)
                            .frame(width: 58)
                            .background(Theme.TransactionColors.color(for: transaction.type).opacity(0.2))
                            .cornerRadius(Theme.CornerRadius.small)
                        Text(asset?.symbol ?? "Unknown")
                            .fontWeight(.semibold)
                    }
                    Text("\(transaction.shares, specifier: "%.4f") @ \(transaction.pricePerShare, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Center: Arrow pointing left (money flows from cash to purchase)
            Image(systemName: "arrow.left")
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, Theme.Spacing.md)

            Spacer()

            // Right side: Cash transaction (source of funds)
            if let linkedTx = linkedTransaction {
                HStack(spacing: Theme.Spacing.sm) {
                    // Cash info: CASH symbol first, then tag
                    VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(linkedAsset?.symbol ?? "Cash")
                                .fontWeight(.medium)
                            Text(linkedTx.type.displayName)
                                .font(.caption)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, Theme.Spacing.xxs)
                                .background(Theme.TransactionColors.color(for: linkedTx.type).opacity(0.2))
                                .cornerRadius(Theme.CornerRadius.small)
                        }
                        Text(linkedTx.totalAmount, format: .currency(code: "USD"))
                            .font(.caption)
                            .foregroundColor(linkedTx.type == .withdrawal ? Theme.StatusColors.negative : Theme.StatusColors.positive)
                    }

                    // Icon
                    ZStack {
                        Circle()
                            .fill(Theme.TransactionColors.color(for: linkedTx.type).opacity(0.2))
                            .frame(width: 36, height: 36)
                        Image(systemName: linkedTx.type.iconName)
                            .foregroundColor(Theme.TransactionColors.color(for: linkedTx.type))
                            .font(.system(size: 16))
                    }
                }
            }

            // Date (fixed position at end)
            Text(transaction.date, style: .date)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 85, alignment: .trailing)
                .padding(.leading, Theme.Spacing.md)

            // Indicators
            HStack(spacing: Theme.Spacing.xs) {
                if transaction.notes != nil {
                    Image(systemName: "note.text")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                if transaction.linkedPlanId != nil {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .frame(width: 30)
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Add Transaction Sheet

struct AddTransactionSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    var preselectedAsset: Asset?

    @State private var selectedAsset: Asset?
    @State private var transactionType: TransactionType = .buy
    @State private var date = Date()
    @State private var sharesText = ""
    @State private var totalCostText = ""
    @State private var notes = ""
    @State private var linkedPlan: InvestmentPlan?
    @State private var isLoadingPrice = false
    @State private var currentPrice: Double?

    var shares: Double {
        Double(sharesText) ?? 0
    }

    var totalCost: Double {
        Double(totalCostText) ?? 0
    }

    /// Calculate average price per share from total cost
    var pricePerShare: Double {
        guard shares > 0 else { return 0 }
        return totalCost / shares
    }

    var isCashOrIncomeTransaction: Bool {
        transactionType == .deposit || transactionType == .withdrawal ||
        transactionType == .dividend || transactionType == .interest
    }

    var totalAmount: Double {
        if isCashOrIncomeTransaction {
            return totalCost // For cash/income, totalCost field holds the total amount
        }
        return totalCost
    }

    var isValid: Bool {
        guard selectedAsset != nil else { return false }

        if isCashOrIncomeTransaction {
            // For deposit/withdrawal/dividend/interest, only amount is needed
            return totalCost > 0
        } else {
            // For buy/sell, need both shares and total cost
            return shares > 0 && totalCost > 0
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Transaction")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Asset") {
                    Picker("Select Asset", selection: $selectedAsset) {
                        Text("Choose an asset...").tag(nil as Asset?)
                        ForEach(databaseService.assets) { asset in
                            HStack {
                                Text(asset.symbol)
                                Text("- \(asset.name)")
                                    .foregroundColor(.secondary)
                            }
                            .tag(asset as Asset?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Transaction Details") {
                    Picker("Type", selection: $transactionType) {
                        // Show appropriate transaction types based on asset type
                        let types = selectedAsset?.type == .cash ? TransactionType.cashTypes : TransactionType.tradingTypes
                        ForEach(types, id: \.self) { type in
                            Label(type.displayName, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    if transactionType == .dividend || transactionType == .interest || transactionType == .deposit || transactionType == .withdrawal {
                        HStack {
                            TextField("Amount", text: $totalCostText)
                                .textFieldStyle(.roundedBorder)
                            Text("USD")
                                .foregroundColor(.secondary)
                        }

                        // Show cash balance for buy transactions
                        if selectedAsset?.type != .cash, let cashBalance = viewModel.cashBalance as Double? {
                            HStack {
                                Image(systemName: "banknote")
                                    .foregroundColor(.secondary)
                                Text("Cash Available: \(cashBalance, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Shares")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("Shares", text: $sharesText)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Cost")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        TextField("Total Cost", text: $totalCostText)
                                            .textFieldStyle(.roundedBorder)
                                        Text("USD")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }

                                Button(action: fetchCurrentPrice) {
                                    if isLoadingPrice {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(selectedAsset == nil || selectedAsset?.type == .cd || selectedAsset?.type == .cash || isLoadingPrice)
                                .help("Fetch current price to calculate total")
                            }

                            // Show calculated average price
                            if shares > 0 && totalCost > 0 {
                                HStack {
                                    Image(systemName: "function")
                                        .foregroundColor(.blue)
                                    Text("Average Price: \(pricePerShare, format: .currency(code: "USD"))")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    if let price = currentPrice {
                                        let diff = ((pricePerShare - price) / price) * 100
                                        Text("(\(diff >= 0 ? "+" : "")\(diff, specifier: "%.1f")% vs market)")
                                            .font(.caption)
                                            .foregroundColor(abs(diff) < 1 ? Theme.StatusColors.positive : Theme.StatusColors.warning)
                                    }
                                }
                            }
                        }

                        // Show cash balance for buy transactions
                        if transactionType == .buy, let cashBalance = viewModel.cashBalance as Double? {
                            HStack {
                                Image(systemName: "banknote")
                                    .foregroundColor(totalAmount > cashBalance ? Theme.StatusColors.negative : Theme.StatusColors.positive)
                                Text("Cash Available: \(cashBalance, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundColor(totalAmount > cashBalance ? .red : .secondary)
                                if totalAmount > cashBalance {
                                    Text("(Insufficient)")
                                        .font(.caption)
                                        .foregroundColor(Theme.StatusColors.negative)
                                }
                            }
                        }
                    }
                }

                // Link to DCA Plan
                if let asset = selectedAsset {
                    let plans = databaseService.getPlans(for: asset.id).filter { $0.status == .active }
                    if !plans.isEmpty && transactionType == .buy {
                        Section("Link to Investment Plan") {
                            Picker("DCA Plan", selection: $linkedPlan) {
                                Text("None").tag(nil as InvestmentPlan?)
                                ForEach(plans) { plan in
                                    Text("$\(plan.amountPerPurchase, specifier: "%.2f") (\(plan.completedPurchases)/\(plan.numberOfPurchases) complete)")
                                        .tag(plan as InvestmentPlan?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Preview
                if isValid {
                    Section("Summary") {
                        if isCashOrIncomeTransaction {
                            HStack {
                                Text(transactionType == .withdrawal ? "Withdraw Amount" : "Amount")
                                Spacer()
                                Text(totalAmount, format: .currency(code: "USD"))
                                    .fontWeight(.semibold)
                                    .foregroundColor(transactionType == .withdrawal ? Theme.StatusColors.negative : Theme.StatusColors.positive)
                            }
                        } else {
                            HStack {
                                Text("Total Amount")
                                Spacer()
                                Text(totalAmount, format: .currency(code: "USD"))
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Add Transaction") {
                    addTransaction()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
        .onAppear {
            if let preselected = preselectedAsset {
                selectedAsset = preselected
            }
        }
        .onChange(of: selectedAsset) { _, newAsset in
            // Reset transaction type based on asset type
            if let asset = newAsset {
                if asset.type == .cash {
                    transactionType = .deposit
                } else if transactionType == .deposit || transactionType == .withdrawal {
                    transactionType = .buy
                }
            }
        }
        .onChange(of: linkedPlan) { _, newPlan in
            if let plan = newPlan {
                sharesText = ""
                totalCostText = String(format: "%.2f", plan.amountPerPurchase)
            }
        }
    }

    private func fetchCurrentPrice() {
        guard let asset = selectedAsset, asset.type != .cd, asset.type != .cash else { return }

        isLoadingPrice = true

        Task {
            do {
                let quote = try await YahooFinanceService.shared.fetchQuote(symbol: asset.symbol)
                currentPrice = quote.price
                // If shares are already entered, calculate total cost
                if shares > 0 {
                    totalCostText = String(format: "%.2f", quote.price * shares)
                }
            } catch {
                // Ignore error, user can enter manually
            }
            isLoadingPrice = false
        }
    }

    private func addTransaction() {
        guard let asset = selectedAsset else { return }

        let isCashTransaction = transactionType == .dividend || transactionType == .interest || transactionType == .deposit || transactionType == .withdrawal
        let finalShares = isCashTransaction ? 1 : shares
        let finalPrice = isCashTransaction ? totalCost : pricePerShare

        // For cash assets, don't update cash (it IS the cash)
        let updateCash = asset.type != .cash

        viewModel.addTransaction(
            asset: asset,
            type: transactionType,
            date: date,
            shares: finalShares,
            pricePerShare: finalPrice,
            notes: notes.isEmpty ? nil : notes,
            linkedPlanId: linkedPlan?.id,
            updateCash: updateCash
        )

        dismiss()
    }
}

// MARK: - Edit Transaction Sheet

struct EditTransactionSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    let transaction: Transaction

    @State private var date: Date
    @State private var sharesText: String
    @State private var totalCostText: String
    @State private var notes: String
    @State private var isLoadingPrice = false
    @State private var currentPrice: Double?

    var asset: Asset? {
        databaseService.getAsset(byId: transaction.assetId)
    }

    var shares: Double {
        Double(sharesText) ?? 0
    }

    var totalCost: Double {
        Double(totalCostText) ?? 0
    }

    var pricePerShare: Double {
        guard shares > 0 else { return 0 }
        return totalCost / shares
    }

    var isCashOrIncomeTransaction: Bool {
        transaction.type == .deposit || transaction.type == .withdrawal ||
        transaction.type == .dividend || transaction.type == .interest
    }

    var isValid: Bool {
        if isCashOrIncomeTransaction {
            return totalCost > 0
        } else {
            return shares > 0 && totalCost > 0
        }
    }

    init(transaction: Transaction) {
        self.transaction = transaction
        _date = State(initialValue: transaction.date)
        _sharesText = State(initialValue: String(format: "%.4f", transaction.shares))
        _totalCostText = State(initialValue: String(format: "%.2f", transaction.totalAmount))
        _notes = State(initialValue: transaction.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit Transaction")
                        .font(.headline)
                    Text("\(asset?.symbol ?? "Unknown") - \(transaction.type.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Transaction Details") {
                    // Type is read-only
                    HStack {
                        Text("Type")
                        Spacer()
                        Label(transaction.type.displayName, systemImage: transaction.type.iconName)
                            .foregroundColor(.secondary)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    if isCashOrIncomeTransaction {
                        HStack {
                            TextField("Amount", text: $totalCostText)
                                .textFieldStyle(.roundedBorder)
                            Text("USD")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Shares")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    TextField("Shares", text: $sharesText)
                                        .textFieldStyle(.roundedBorder)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Cost")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        TextField("Total Cost", text: $totalCostText)
                                            .textFieldStyle(.roundedBorder)
                                        Text("USD")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                }

                                Button(action: fetchCurrentPrice) {
                                    if isLoadingPrice {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.down.circle")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(asset?.type == .cd || asset?.type == .cash || isLoadingPrice)
                                .help("Fetch current price to calculate total")
                            }

                            // Show calculated average price
                            if shares > 0 && totalCost > 0 {
                                HStack {
                                    Image(systemName: "function")
                                        .foregroundColor(.blue)
                                    Text("Average Price: \(pricePerShare, format: .currency(code: "USD"))")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    if let price = currentPrice {
                                        let diff = ((pricePerShare - price) / price) * 100
                                        Text("(\(diff >= 0 ? "+" : "")\(diff, specifier: "%.1f")% vs market)")
                                            .font(.caption)
                                            .foregroundColor(abs(diff) < 1 ? Theme.StatusColors.positive : Theme.StatusColors.warning)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                }

                // Summary
                if isValid {
                    Section("Summary") {
                        HStack {
                            Text("Total Amount")
                            Spacer()
                            Text(totalCost, format: .currency(code: "USD"))
                                .fontWeight(.semibold)
                        }

                        // Show original values for comparison
                        if totalCost != transaction.totalAmount || shares != transaction.shares {
                            HStack {
                                Text("Original")
                                Spacer()
                                Text("\(transaction.shares, specifier: "%.4f") shares @ \(transaction.pricePerShare, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                // Linked transaction info
                if let linkedTxId = transaction.linkedTransactionId,
                   let linkedTx = databaseService.transactions.first(where: { $0.id == linkedTxId }),
                   let linkedAsset = databaseService.getAsset(byId: linkedTx.assetId) {
                    Section("Linked Transaction") {
                        HStack {
                            Image(systemName: linkedTx.type.iconName)
                                .foregroundColor(linkedTx.type == .withdrawal ? Theme.StatusColors.negative : Theme.StatusColors.positive)
                            Text("\(linkedAsset.symbol) \(linkedTx.type.displayName)")
                            Spacer()
                            Text(linkedTx.totalAmount, format: .currency(code: "USD"))
                                .foregroundColor(linkedTx.type == .withdrawal ? Theme.StatusColors.negative : Theme.StatusColors.positive)
                        }
                        Text("This will also be updated")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Save Changes") {
                    saveChanges()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 500)
    }

    private func fetchCurrentPrice() {
        guard let asset = asset, asset.type != .cd && asset.type != .cash else { return }

        isLoadingPrice = true

        Task {
            do {
                let quote = try await YahooFinanceService.shared.fetchQuote(symbol: asset.symbol)
                currentPrice = quote.price
                if shares > 0 {
                    totalCostText = String(format: "%.2f", quote.price * shares)
                }
            } catch {
                // Ignore error
            }
            isLoadingPrice = false
        }
    }

    private func saveChanges() {
        let finalShares = isCashOrIncomeTransaction ? 1 : shares
        let finalPrice = isCashOrIncomeTransaction ? totalCost : pricePerShare

        var updatedTransaction = transaction
        updatedTransaction.date = date
        updatedTransaction.shares = finalShares
        updatedTransaction.pricePerShare = finalPrice
        updatedTransaction.notes = notes.isEmpty ? nil : notes

        viewModel.updateTransaction(updatedTransaction, updateLinkedCash: true)
        dismiss()
    }
}

#Preview {
    TransactionsView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
