import Foundation
import WidgetKit

/// Manages data sharing between the main app and widget extension via App Groups
@MainActor
class SharedDataManager {
    static let shared = SharedDataManager()

    private let suiteName = "group.JinWookShin.AssetMonitor"
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    // MARK: - Keys

    private enum Keys {
        static let totalValue = "totalValue"
        static let dailyChange = "dailyChange"
        static let dailyChangePercent = "dailyChangePercent"
        static let topHoldings = "topHoldings"
        static let lastUpdated = "lastUpdated"
        static let dcaPlans = "dcaPlans"
        static let stockNews = "stockNews"
        static let privacyMode = "privacyMode"
    }

    // MARK: - Privacy Mode

    var isPrivacyModeEnabled: Bool {
        get {
            defaults?.bool(forKey: Keys.privacyMode) ?? false
        }
        set {
            defaults?.set(newValue, forKey: Keys.privacyMode)
            defaults?.synchronize()
            // Reload all widget timelines when privacy mode changes
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Update Portfolio Widget Data

    func updateWidgetData(
        totalValue: Double,
        dailyChange: Double,
        dailyChangePercent: Double,
        holdings: [WidgetHoldingData]
    ) {
        guard let defaults = defaults else {
            print("SharedDataManager: Could not access App Group UserDefaults")
            return
        }

        defaults.set(totalValue, forKey: Keys.totalValue)
        defaults.set(dailyChange, forKey: Keys.dailyChange)
        defaults.set(dailyChangePercent, forKey: Keys.dailyChangePercent)
        defaults.set(Date(), forKey: Keys.lastUpdated)

        if let data = try? JSONEncoder().encode(holdings) {
            defaults.set(data, forKey: Keys.topHoldings)
        }

        // Force immediate persistence for cross-process communication
        defaults.synchronize()

        WidgetCenter.shared.reloadTimelines(ofKind: "AssetMonitorWidget")
    }

    // MARK: - Update DCA Plans Widget Data

    func updateDCAPlansData(plans: [WidgetDCAPlanData]) {
        guard let defaults = defaults else { return }

        if let data = try? JSONEncoder().encode(plans) {
            defaults.set(data, forKey: Keys.dcaPlans)
        }
        defaults.set(Date(), forKey: Keys.lastUpdated)

        // Force immediate persistence for cross-process communication
        defaults.synchronize()

        WidgetCenter.shared.reloadTimelines(ofKind: "DCAPlansWidget")
    }

    // MARK: - Update News Widget Data

    func updateNewsData(news: [WidgetNewsData]) {
        guard let defaults = defaults else { return }

        if let data = try? JSONEncoder().encode(news) {
            defaults.set(data, forKey: Keys.stockNews)
        }
        defaults.set(Date(), forKey: Keys.lastUpdated)

        // Force immediate persistence for cross-process communication
        defaults.synchronize()

        WidgetCenter.shared.reloadTimelines(ofKind: "StockNewsWidget")
    }

    // MARK: - Sync All Data from Main App

    func syncFromMainApp(assets: [Asset]) {
        let totalValue = assets.reduce(0) { $0 + $1.totalValue }

        let dailyChange = assets.reduce(0) { total, asset in
            total + (asset.totalShares * asset.dailyChange)
        }

        let previousValue = totalValue - dailyChange
        let dailyChangePercent = previousValue > 0 ? (dailyChange / previousValue) * 100 : 0

        let topHoldings = assets
            .sorted { $0.totalValue > $1.totalValue }
            .prefix(6)
            .map { asset in
                WidgetHoldingData(
                    symbol: asset.symbol,
                    price: asset.currentPrice ?? asset.averageCost,
                    changePercent: asset.dailyChangePercent,
                    value: asset.totalValue
                )
            }

        updateWidgetData(
            totalValue: totalValue,
            dailyChange: dailyChange,
            dailyChangePercent: dailyChangePercent,
            holdings: Array(topHoldings)
        )
    }

    func syncDCAPlans(plans: [InvestmentPlan], assets: [Asset]) {
        let activePlans = plans.filter { $0.status == .active }

        let widgetPlans = activePlans.compactMap { plan -> WidgetDCAPlanData? in
            guard let asset = assets.first(where: { $0.id == plan.assetId }) else { return nil }

            return WidgetDCAPlanData(
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
                timing: nil // Will be updated separately with async call
            )
        }

        updateDCAPlansData(plans: widgetPlans)
    }

    func syncNews(news: [StockNews]) {
        let widgetNews = news.prefix(10).map { item in
            WidgetNewsData(
                id: item.id,
                symbol: item.symbol,
                title: item.title,
                publisher: item.publisher,
                publishedDate: item.publishedDate,
                link: item.link
            )
        }

        updateNewsData(news: Array(widgetNews))
    }

    // MARK: - Read Widget Data

    func readWidgetData() -> (
        totalValue: Double,
        dailyChange: Double,
        dailyChangePercent: Double,
        holdings: [WidgetHoldingData],
        lastUpdated: Date?
    ) {
        guard let defaults = defaults else {
            return (0, 0, 0, [], nil)
        }

        let totalValue = defaults.double(forKey: Keys.totalValue)
        let dailyChange = defaults.double(forKey: Keys.dailyChange)
        let dailyChangePercent = defaults.double(forKey: Keys.dailyChangePercent)
        let lastUpdated = defaults.object(forKey: Keys.lastUpdated) as? Date

        var holdings: [WidgetHoldingData] = []
        if let data = defaults.data(forKey: Keys.topHoldings),
           let decoded = try? JSONDecoder().decode([WidgetHoldingData].self, from: data) {
            holdings = decoded
        }

        return (totalValue, dailyChange, dailyChangePercent, holdings, lastUpdated)
    }

    func readDCAPlansData() -> [WidgetDCAPlanData] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: Keys.dcaPlans),
              let decoded = try? JSONDecoder().decode([WidgetDCAPlanData].self, from: data) else {
            return []
        }
        return decoded
    }

    func readNewsData() -> [WidgetNewsData] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: Keys.stockNews),
              let decoded = try? JSONDecoder().decode([WidgetNewsData].self, from: data) else {
            return []
        }
        return decoded
    }

    // MARK: - Clear Data

    func clearWidgetData() {
        defaults?.removeObject(forKey: Keys.totalValue)
        defaults?.removeObject(forKey: Keys.dailyChange)
        defaults?.removeObject(forKey: Keys.dailyChangePercent)
        defaults?.removeObject(forKey: Keys.topHoldings)
        defaults?.removeObject(forKey: Keys.dcaPlans)
        defaults?.removeObject(forKey: Keys.stockNews)
        defaults?.removeObject(forKey: Keys.lastUpdated)

        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Widget Data Models (Shared between app and widget)

struct WidgetHoldingData: Codable {
    let symbol: String
    let price: Double
    let changePercent: Double
    let value: Double
}

struct WidgetDCAPlanData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let assetName: String
    let currentHoldings: Double      // Current value of holdings
    let currentShares: Double        // Number of shares owned
    let currentPrice: Double         // Current stock price
    let dailyChangePercent: Double   // Today's price change
    let totalPlanAmount: Double      // Total planned investment
    let completedPurchases: Int      // How many purchases done
    let totalPurchases: Int          // Total planned purchases
    let nextPurchaseAmount: Double   // Amount for next purchase
    let nextPurchaseDate: Date?      // When to buy next
    let isOverdue: Bool              // Is the purchase overdue
    var timing: WidgetTimingData?    // Is it a good time to buy

    var progressPercent: Double {
        guard totalPurchases > 0 else { return 0 }
        return Double(completedPurchases) / Double(totalPurchases) * 100
    }

    var remainingAmount: Double {
        return Double(totalPurchases - completedPurchases) * nextPurchaseAmount
    }
}

struct WidgetTimingData: Codable {
    let recommendation: String       // "good", "neutral", "wait"
    let reason: String
    let percentFromAverage: Double?

    var isGoodTime: Bool {
        return recommendation == "good"
    }

    var displayText: String {
        switch recommendation {
        case "good": return "Good Time to Buy"
        case "wait": return "Consider Waiting"
        default: return "Neutral"
        }
    }

    var iconName: String {
        switch recommendation {
        case "good": return "checkmark.circle.fill"
        case "wait": return "clock.fill"
        default: return "minus.circle.fill"
        }
    }
}

struct WidgetNewsData: Codable, Identifiable {
    let id: UUID
    let symbol: String
    let title: String
    let publisher: String
    let publishedDate: Date
    let link: String

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedDate, relativeTo: Date())
    }
}
