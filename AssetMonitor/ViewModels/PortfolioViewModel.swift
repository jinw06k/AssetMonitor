import Foundation
import Combine

/// Main view model for portfolio management
@MainActor
class PortfolioViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var lastRefreshed: Date?
    @Published var errorMessage: String?

    @Published var selectedTab: AppTab = .dashboard
    @Published var selectedAsset: Asset?

    @Published var aiAnalysis: PortfolioAnalysis?
    @Published var isAnalyzing = false

    @Published var stockNews: [StockNews] = []
    @Published var isLoadingNews = false

    @Published var isPrivacyModeEnabled: Bool {
        didSet {
            SharedDataManager.shared.isPrivacyModeEnabled = isPrivacyModeEnabled
        }
    }

    // MARK: - Initialization

    init() {
        // Load privacy mode state from shared storage
        isPrivacyModeEnabled = SharedDataManager.shared.isPrivacyModeEnabled
    }

    // MARK: - Computed Properties

    var totalPortfolioValue: Double {
        DatabaseService.shared.assets.reduce(0) { $0 + $1.totalValue }
    }

    var totalCost: Double {
        DatabaseService.shared.assets.reduce(0) { $0 + $1.totalCost }
    }

    var totalGainLoss: Double {
        totalPortfolioValue - totalCost
    }

    var totalGainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalGainLoss / totalCost) * 100
    }

    var dailyChange: Double {
        DatabaseService.shared.assets.reduce(0) { total, asset in
            let shares = asset.totalShares
            let change = asset.dailyChange
            return total + (shares * change)
        }
    }

    var dailyChangePercent: Double {
        let previousValue = totalPortfolioValue - dailyChange
        guard previousValue > 0 else { return 0 }
        return (dailyChange / previousValue) * 100
    }

    var stocksValue: Double {
        DatabaseService.shared.assets.filter { $0.type == .stock }.reduce(0) { $0 + $1.totalValue }
    }

    var etfsValue: Double {
        DatabaseService.shared.assets.filter { $0.type == .etf }.reduce(0) { $0 + $1.totalValue }
    }

    var treasuryValue: Double {
        DatabaseService.shared.assets.filter { $0.type == .treasury }.reduce(0) { $0 + $1.totalValue }
    }

    var cdsValue: Double {
        DatabaseService.shared.assets.filter { $0.type == .cd }.reduce(0) { $0 + ($1.cdCurrentValue ?? $1.totalCost) }
    }

    var cashBalance: Double {
        DatabaseService.shared.assets.filter { $0.type == .cash }.reduce(0) { $0 + $1.totalValue }
    }

    var cashAsset: Asset? {
        DatabaseService.shared.assets.first { $0.type == .cash }
    }

    var allocationData: [AllocationItem] {
        let total = totalPortfolioValue
        guard total > 0 else { return [] }

        return DatabaseService.shared.assets
            .sorted { $0.totalValue > $1.totalValue }
            .map { asset in
                AllocationItem(
                    name: asset.symbol,
                    value: asset.totalValue,
                    percentage: (asset.totalValue / total) * 100,
                    type: asset.type
                )
            }
    }

    var typeAllocationData: [AllocationItem] {
        let total = totalPortfolioValue
        guard total > 0 else { return [] }

        var items: [AllocationItem] = []

        if stocksValue > 0 {
            items.append(AllocationItem(name: "Stocks", value: stocksValue, percentage: (stocksValue / total) * 100, type: .stock))
        }
        if etfsValue > 0 {
            items.append(AllocationItem(name: "ETFs", value: etfsValue, percentage: (etfsValue / total) * 100, type: .etf))
        }
        if treasuryValue > 0 {
            items.append(AllocationItem(name: "Treasury", value: treasuryValue, percentage: (treasuryValue / total) * 100, type: .treasury))
        }
        if cdsValue > 0 {
            items.append(AllocationItem(name: "CDs", value: cdsValue, percentage: (cdsValue / total) * 100, type: .cd))
        }
        if cashBalance > 0 {
            items.append(AllocationItem(name: "Cash", value: cashBalance, percentage: (cashBalance / total) * 100, type: .cash))
        }

        return items.sorted { $0.value > $1.value }
    }

    var activePlans: [InvestmentPlan] {
        DatabaseService.shared.investmentPlans.filter { $0.status == .active }
    }

    var overduePlans: [InvestmentPlan] {
        activePlans.filter { $0.isOverdue }
    }

    // MARK: - Price Refresh

    func refreshPrices() async {
        guard !isRefreshing else { return }

        isRefreshing = true
        errorMessage = nil

        let symbols = DatabaseService.shared.assets
            .filter { $0.type != .cd && $0.type != .cash }
            .map { $0.symbol }

        guard !symbols.isEmpty else {
            isRefreshing = false
            lastRefreshed = Date()
            return
        }

        let quotes = await YahooFinanceService.shared.fetchQuotes(symbols: symbols)

        // Batch the updates to avoid multiple view refreshes
        var updates: [(Int, Double, Double)] = []

        for (symbol, quote) in quotes {
            // Find index and prepare update
            if let index = DatabaseService.shared.assets.firstIndex(where: { $0.symbol == symbol }) {
                updates.append((index, quote.price, quote.previousClose))
            }

            // Cache price
            DatabaseService.shared.cachePrice(
                symbol: symbol,
                price: quote.price,
                previousClose: quote.previousClose,
                changePercent: quote.changePercent
            )
        }

        // Apply all updates at once
        for (index, price, previousClose) in updates {
            DatabaseService.shared.assets[index].currentPrice = price
            DatabaseService.shared.assets[index].previousClose = previousClose
        }

        lastRefreshed = Date()
        isRefreshing = false

        // Sync to widgets
        syncAllWidgetData()
    }

    // MARK: - Widget Data Sync

    func syncAllWidgetData() {
        // Sync portfolio data
        SharedDataManager.shared.syncFromMainApp(assets: DatabaseService.shared.assets)

        // Sync DCA plans with timing analysis
        syncDCAPlansToWidget()

        // Sync news
        if !stockNews.isEmpty {
            SharedDataManager.shared.syncNews(news: stockNews)
        }
    }

    private func syncDCAPlansToWidget() {
        let assets = DatabaseService.shared.assets
        let plans = DatabaseService.shared.investmentPlans.filter { $0.status == .active }

        var widgetPlans: [WidgetDCAPlanData] = []

        for plan in plans {
            guard let asset = assets.first(where: { $0.id == plan.assetId }) else { continue }

            var widgetPlan = WidgetDCAPlanData(
                id: plan.id,
                symbol: asset.symbol,
                assetName: asset.name,
                currentHoldings: asset.totalValue,
                currentShares: asset.totalShares,
                currentPrice: asset.currentPrice ?? asset.averageCost,
                dailyChangePercent: asset.dailyChangePercent,
                totalPlanAmount: plan.totalAmount,
                completedPurchases: plan.completedPurchases,
                totalPurchases: plan.numberOfPurchases,
                nextPurchaseAmount: plan.amountPerPurchase,
                nextPurchaseDate: plan.nextPurchaseDate,
                isOverdue: plan.isOverdue,
                timing: nil
            )

            // Add timing analysis asynchronously
            Task {
                let timing = await NewsService.shared.analyzeTimingForPurchase(symbol: asset.symbol)
                widgetPlan.timing = WidgetTimingData(
                    recommendation: timing.recommendation.rawValue,
                    reason: timing.reason,
                    percentFromAverage: timing.percentFromAverage
                )
            }

            widgetPlans.append(widgetPlan)
        }

        SharedDataManager.shared.updateDCAPlansData(plans: widgetPlans)
    }

    // MARK: - News Fetching

    func refreshNews() async {
        guard !isLoadingNews else { return }

        isLoadingNews = true

        let symbols = DatabaseService.shared.assets
            .filter { $0.type != .cd && $0.type != .cash }
            .map { $0.symbol }

        guard !symbols.isEmpty else {
            isLoadingNews = false
            return
        }

        stockNews = await NewsService.shared.fetchNews(for: symbols, limit: 15)
        SharedDataManager.shared.syncNews(news: stockNews)

        isLoadingNews = false
    }

    // MARK: - AI Analysis

    func requestAIAnalysis() async {
        guard !isAnalyzing else { return }
        guard OpenAIService.shared.isConfigured else {
            errorMessage = "Please configure your OpenAI API key in Settings"
            return
        }

        isAnalyzing = true
        errorMessage = nil

        do {
            let analysis = try await OpenAIService.shared.analyzePortfolio(
                assets: DatabaseService.shared.assets,
                transactions: DatabaseService.shared.transactions,
                plans: DatabaseService.shared.investmentPlans
            )
            aiAnalysis = analysis
        } catch {
            errorMessage = error.localizedDescription
        }

        isAnalyzing = false
    }

    // MARK: - Asset Management

    func addAsset(symbol: String, type: AssetType, name: String, cdMaturityDate: Date? = nil, cdInterestRate: Double? = nil) async {
        var asset = Asset(
            symbol: symbol,
            type: type,
            name: name,
            cdMaturityDate: cdMaturityDate,
            cdInterestRate: cdInterestRate
        )

        // Fetch current price for stocks/ETFs/Treasury (not for CDs or Cash)
        if type == .stock || type == .etf || type == .treasury {
            do {
                let quote = try await YahooFinanceService.shared.fetchQuote(symbol: symbol)
                asset.currentPrice = quote.price
                asset.previousClose = quote.previousClose

                // Use fetched name if we don't have a custom one
                if name.isEmpty || name == symbol {
                    asset.name = quote.name
                }
            } catch {
                // Continue without price
                print("Could not fetch price for \(symbol): \(error)")
            }
        } else if type == .cash {
            // Cash always has a "price" of 1.0
            asset.currentPrice = 1.0
            asset.previousClose = 1.0
        }

        DatabaseService.shared.addAsset(asset)
        syncAllWidgetData()
    }

    func deleteAsset(_ asset: Asset) {
        DatabaseService.shared.deleteAsset(asset)
        syncAllWidgetData()
    }

    // MARK: - Transaction Management

    func addTransaction(
        asset: Asset,
        type: TransactionType,
        date: Date,
        shares: Double,
        pricePerShare: Double,
        notes: String?,
        linkedPlanId: UUID?,
        updateCash: Bool = true
    ) {
        var transaction = Transaction(
            assetId: asset.id,
            type: type,
            date: date,
            shares: shares,
            pricePerShare: pricePerShare,
            notes: notes,
            linkedPlanId: linkedPlanId
        )

        // Update cash balance if applicable and not a cash transaction itself
        if updateCash && asset.type != .cash, let cashAsset = cashAsset {
            let amount = shares * pricePerShare
            switch type {
            case .buy:
                // Deduct from cash when buying - create linked withdrawal
                var cashTx = Transaction(
                    assetId: cashAsset.id,
                    type: .withdrawal,
                    date: date,
                    shares: 1,
                    pricePerShare: amount,
                    notes: "Purchase: \(asset.symbol)",
                    linkedPlanId: nil,
                    linkedTransactionId: transaction.id
                )
                // Link the BUY to the withdrawal
                transaction.linkedTransactionId = cashTx.id
                DatabaseService.shared.addTransaction(transaction)
                DatabaseService.shared.addTransaction(cashTx)
            case .sell:
                // Add to cash when selling - create linked deposit
                var cashTx = Transaction(
                    assetId: cashAsset.id,
                    type: .deposit,
                    date: date,
                    shares: 1,
                    pricePerShare: amount,
                    notes: "Sale: \(asset.symbol)",
                    linkedPlanId: nil,
                    linkedTransactionId: transaction.id
                )
                transaction.linkedTransactionId = cashTx.id
                DatabaseService.shared.addTransaction(transaction)
                DatabaseService.shared.addTransaction(cashTx)
            case .dividend, .interest:
                // Dividends and interest go to cash - create linked deposit
                var cashTx = Transaction(
                    assetId: cashAsset.id,
                    type: .deposit,
                    date: date,
                    shares: 1,
                    pricePerShare: amount,
                    notes: "\(type.displayName): \(asset.symbol)",
                    linkedPlanId: nil,
                    linkedTransactionId: transaction.id
                )
                transaction.linkedTransactionId = cashTx.id
                DatabaseService.shared.addTransaction(transaction)
                DatabaseService.shared.addTransaction(cashTx)
            default:
                DatabaseService.shared.addTransaction(transaction)
            }
        } else {
            DatabaseService.shared.addTransaction(transaction)
        }

        // If linked to a plan, update the plan
        if let planId = linkedPlanId,
           var plan = DatabaseService.shared.investmentPlans.first(where: { $0.id == planId }) {
            plan.recordPurchase()
            DatabaseService.shared.updateInvestmentPlan(plan)
        }

        syncAllWidgetData()
    }

    func updateTransaction(_ transaction: Transaction, updateLinkedCash: Bool = true) {
        DatabaseService.shared.updateTransaction(transaction)

        // Update linked cash transaction if needed
        if updateLinkedCash, let linkedTxId = transaction.linkedTransactionId {
            if var linkedTx = DatabaseService.shared.transactions.first(where: { $0.id == linkedTxId }) {
                linkedTx.date = transaction.date
                linkedTx.pricePerShare = transaction.totalAmount
                if let asset = DatabaseService.shared.getAsset(byId: transaction.assetId) {
                    if transaction.type == .buy {
                        linkedTx.notes = "Purchase: \(asset.symbol)"
                    } else if transaction.type == .sell {
                        linkedTx.notes = "Sale: \(asset.symbol)"
                    } else if transaction.type == .dividend || transaction.type == .interest {
                        linkedTx.notes = "\(transaction.type.displayName): \(asset.symbol)"
                    }
                }
                DatabaseService.shared.updateTransaction(linkedTx)
            }
        }

        syncAllWidgetData()
    }

    func deleteTransaction(_ transaction: Transaction, deleteLinked: Bool = true) {
        // Also delete linked transaction if exists
        if deleteLinked, let linkedTxId = transaction.linkedTransactionId {
            if let linkedTx = DatabaseService.shared.transactions.first(where: { $0.id == linkedTxId }) {
                DatabaseService.shared.deleteTransaction(linkedTx)
            }
        }

        DatabaseService.shared.deleteTransaction(transaction)
        syncAllWidgetData()
    }

    // MARK: - Plan Management

    func addInvestmentPlan(
        asset: Asset,
        totalAmount: Double,
        numberOfPurchases: Int,
        frequency: PlanFrequency,
        customDays: Int?,
        startDate: Date,
        notes: String?
    ) {
        let plan = InvestmentPlan(
            assetId: asset.id,
            totalAmount: totalAmount,
            numberOfPurchases: numberOfPurchases,
            frequency: frequency,
            customDaysBetween: customDays,
            startDate: startDate,
            notes: notes
        )

        DatabaseService.shared.addInvestmentPlan(plan)
        syncAllWidgetData()
    }

    func updatePlan(_ plan: InvestmentPlan) {
        DatabaseService.shared.updateInvestmentPlan(plan)
        syncAllWidgetData()
    }

    func deletePlan(_ plan: InvestmentPlan) {
        DatabaseService.shared.deleteInvestmentPlan(plan)
        syncAllWidgetData()
    }
}

// MARK: - Supporting Types

enum AppTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case assets = "Assets"
    case transactions = "Transactions"
    case plans = "Plans"
    case news = "News"
    case analysis = "AI Analysis"

    var iconName: String {
        switch self {
        case .dashboard: return "chart.bar.fill"
        case .assets: return "building.columns.fill"
        case .transactions: return "arrow.left.arrow.right"
        case .plans: return "calendar.badge.clock"
        case .news: return "newspaper.fill"
        case .analysis: return "brain"
        }
    }
}

struct AllocationItem: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let percentage: Double
    let type: AssetType
}
