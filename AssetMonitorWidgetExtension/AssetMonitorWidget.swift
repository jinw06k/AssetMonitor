import WidgetKit
import SwiftUI

// ============================================================================
// MARK: - PORTFOLIO WIDGET (Original)
// ============================================================================

struct PortfolioEntry: TimelineEntry {
    let date: Date
    let totalValue: Double
    let dailyChange: Double
    let dailyChangePercent: Double
    let holdings: [WidgetHoldingData]
    let isPlaceholder: Bool
    let isPrivacyMode: Bool

    static var placeholder: PortfolioEntry {
        PortfolioEntry(
            date: Date(),
            totalValue: 125000.00,
            dailyChange: 1250.00,
            dailyChangePercent: 1.01,
            holdings: [
                WidgetHoldingData(symbol: "AAPL", price: 185.50, changePercent: 1.2, value: 37000),
                WidgetHoldingData(symbol: "NVDA", price: 875.00, changePercent: 2.5, value: 26250),
                WidgetHoldingData(symbol: "QQQ", price: 425.00, changePercent: 0.8, value: 21250),
            ],
            isPlaceholder: true,
            isPrivacyMode: false
        )
    }
}

struct PortfolioTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
        completion(loadPortfolioData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
        let entry = loadPortfolioData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadPortfolioData() -> PortfolioEntry {
        let data = SharedDataManager.shared.readWidgetData()
        let isPrivacyMode = SharedDataManager.shared.isPrivacyModeEnabled
        if data.totalValue == 0 && data.holdings.isEmpty {
            var placeholder = PortfolioEntry.placeholder
            return PortfolioEntry(
                date: placeholder.date,
                totalValue: placeholder.totalValue,
                dailyChange: placeholder.dailyChange,
                dailyChangePercent: placeholder.dailyChangePercent,
                holdings: placeholder.holdings,
                isPlaceholder: true,
                isPrivacyMode: isPrivacyMode
            )
        }
        return PortfolioEntry(
            date: Date(),
            totalValue: data.totalValue,
            dailyChange: data.dailyChange,
            dailyChangePercent: data.dailyChangePercent,
            holdings: data.holdings,
            isPlaceholder: false,
            isPrivacyMode: isPrivacyMode
        )
    }
}

// Portfolio Widget Views (Small, Medium, Large)
struct SmallPortfolioView: View {
    let entry: PortfolioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Portfolio")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if entry.isPrivacyMode {
                    Spacer()
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if entry.isPrivacyMode {
                Text("••••••")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            } else {
                Text(entry.totalValue, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }

            HStack(spacing: 4) {
                Image(systemName: entry.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                Text("\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.2f")%")
            }
            .font(.caption)
            .lineLimit(1)
            .foregroundColor(entry.dailyChange >= 0 ? .green : .red)

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct MediumPortfolioView: View {
    let entry: PortfolioEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.blue)
                    Text("Portfolio").font(.caption).foregroundColor(.secondary)
                    if entry.isPrivacyMode {
                        Spacer()
                        Image(systemName: "eye.slash.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                if entry.isPrivacyMode {
                    Text("••••••")
                        .font(.title2).fontWeight(.bold).foregroundColor(.secondary)
                } else {
                    Text(entry.totalValue, format: .currency(code: "USD"))
                        .font(.title2).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.5)
                }
                HStack(spacing: 4) {
                    Image(systemName: entry.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                    if !entry.isPrivacyMode {
                        Text(abs(entry.dailyChange), format: .currency(code: "USD"))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Text("(\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.1f")%)")
                }
                .font(.caption).foregroundColor(entry.dailyChange >= 0 ? .green : .red)
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Top Holdings").font(.caption).foregroundColor(.secondary)
                ForEach(entry.holdings.prefix(4), id: \.symbol) { holding in
                    HStack {
                        Text(holding.symbol).font(.caption).fontWeight(.medium)
                        Spacer()
                        Text("\(holding.changePercent >= 0 ? "+" : "")\(holding.changePercent, specifier: "%.1f")%")
                            .font(.caption).foregroundColor(holding.changePercent >= 0 ? .green : .red)
                    }
                    .lineLimit(1)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct LargePortfolioView: View {
    let entry: PortfolioEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis").foregroundColor(.blue)
                        Text("AssetMonitor").font(.caption).foregroundColor(.secondary)
                        if entry.isPrivacyMode {
                            Image(systemName: "eye.slash.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    if entry.isPrivacyMode {
                        Text("••••••")
                            .font(.title2).fontWeight(.bold).foregroundColor(.secondary)
                    } else {
                        Text(entry.totalValue, format: .currency(code: "USD"))
                            .font(.title2).fontWeight(.bold).lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Today").font(.caption).foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: entry.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                        if entry.isPrivacyMode {
                            Text("\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.1f")%")
                        } else {
                            Text(abs(entry.dailyChange), format: .currency(code: "USD"))
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .foregroundColor(entry.dailyChange >= 0 ? .green : .red)
                }
            }
            Divider()
            HStack {
                Text("Holdings").font(.caption).foregroundColor(.secondary)
                Spacer()
                Text("\(entry.holdings.count) assets").font(.caption2).foregroundColor(.secondary)
            }
            ForEach(entry.holdings.prefix(10), id: \.symbol) { holding in
                HStack {
                    Text(holding.symbol).fontWeight(.medium)
                    Spacer()
                    if !entry.isPrivacyMode {
                        Text(holding.price, format: .currency(code: "USD"))
                            .foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Text("\(holding.changePercent >= 0 ? "+" : "")\(holding.changePercent, specifier: "%.1f")%")
                        .foregroundColor(holding.changePercent >= 0 ? .green : .red).frame(width: 55, alignment: .trailing)
                    if !entry.isPrivacyMode {
                        Text(holding.value, format: .currency(code: "USD"))
                            .fontWeight(.medium).frame(width: 75, alignment: .trailing).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .font(.caption)
                .lineLimit(1)
            }
            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct AssetMonitorWidget: Widget {
    let kind: String = "AssetMonitorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioTimelineProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Portfolio")
        .description("Track your investment portfolio at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct PortfolioWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: PortfolioEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallPortfolioView(entry: entry)
        case .systemMedium: MediumPortfolioView(entry: entry)
        case .systemLarge: LargePortfolioView(entry: entry)
        default: SmallPortfolioView(entry: entry)
        }
    }
}

// ============================================================================
// MARK: - DCA PLANS WIDGET (New)
// ============================================================================

struct DCAPlansEntry: TimelineEntry {
    let date: Date
    let plans: [WidgetDCAPlanData]
    let isPlaceholder: Bool
    let isPrivacyMode: Bool

    static var placeholder: DCAPlansEntry {
        DCAPlansEntry(
            date: Date(),
            plans: [
                WidgetDCAPlanData(
                    id: UUID(),
                    symbol: "TSLA",
                    assetName: "Tesla Inc.",
                    currentHoldings: 5000.00,
                    currentShares: 12.5,
                    currentPrice: 400.00,
                    dailyChangePercent: 2.5,
                    totalPlanAmount: 10000.00,
                    completedPurchases: 1,
                    totalPurchases: 2,
                    nextPurchaseAmount: 5000.00,
                    nextPurchaseDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
                    isOverdue: false,
                    timing: WidgetTimingData(recommendation: "good", reason: "Price 3% below average", percentFromAverage: -3.0)
                ),
                WidgetDCAPlanData(
                    id: UUID(),
                    symbol: "NVDA",
                    assetName: "NVIDIA",
                    currentHoldings: 8750.00,
                    currentShares: 10.0,
                    currentPrice: 875.00,
                    dailyChangePercent: -1.2,
                    totalPlanAmount: 15000.00,
                    completedPurchases: 2,
                    totalPurchases: 3,
                    nextPurchaseAmount: 5000.00,
                    nextPurchaseDate: Date().addingTimeInterval(-2 * 24 * 60 * 60),
                    isOverdue: true,
                    timing: WidgetTimingData(recommendation: "neutral", reason: "Near average", percentFromAverage: 0.5)
                )
            ],
            isPlaceholder: true,
            isPrivacyMode: false
        )
    }
}

struct DCAPlansTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DCAPlansEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (DCAPlansEntry) -> Void) {
        completion(loadDCAPlansData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DCAPlansEntry>) -> Void) {
        let entry = loadDCAPlansData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadDCAPlansData() -> DCAPlansEntry {
        let plans = SharedDataManager.shared.readDCAPlansData()
        let isPrivacyMode = SharedDataManager.shared.isPrivacyModeEnabled
        if plans.isEmpty {
            let placeholder = DCAPlansEntry.placeholder
            return DCAPlansEntry(
                date: placeholder.date,
                plans: placeholder.plans,
                isPlaceholder: true,
                isPrivacyMode: isPrivacyMode
            )
        }
        return DCAPlansEntry(date: Date(), plans: plans, isPlaceholder: false, isPrivacyMode: isPrivacyMode)
    }
}

// DCA Plans Widget Views
struct SmallDCAPlansView: View {
    let entry: DCAPlansEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Next Buy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if entry.isPrivacyMode {
                    Spacer()
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let plan = entry.plans.first {
                Text(plan.symbol)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)

                if entry.isPrivacyMode {
                    Text("••••")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text(plan.nextPurchaseAmount, format: .currency(code: "USD"))
                        .font(.subheadline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if plan.isOverdue {
                    HStack(spacing: 2) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Overdue")
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                } else if let timing = plan.timing {
                    HStack(spacing: 2) {
                        Image(systemName: timing.iconName)
                        Text(timing.recommendation == "good" ? "Good Time" : "Neutral")
                    }
                    .font(.caption)
                    .foregroundColor(timing.recommendation == "good" ? .green : .orange)
                    .lineLimit(1)
                }
            } else {
                Text("No active plans")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct MediumDCAPlansView: View {
    let entry: DCAPlansEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Investment Plans")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if entry.isPrivacyMode {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("\(entry.plans.count) active")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if entry.plans.isEmpty {
                Spacer()
                Text("No active investment plans")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.plans.prefix(2)) { plan in
                    DCAMediumPlanRow(plan: plan, isPrivacyMode: entry.isPrivacyMode)
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct DCAMediumPlanRow: View {
    let plan: WidgetDCAPlanData
    let isPrivacyMode: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Symbol and Status
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(plan.symbol)
                        .font(.headline)
                        .lineLimit(1)
                    if plan.isOverdue {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                if isPrivacyMode {
                    Text("Own: ••••")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("Own: \(plan.currentHoldings, format: .currency(code: "USD"))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer()

            // Next Purchase
            VStack(alignment: .trailing, spacing: 2) {
                if isPrivacyMode {
                    Text("Next: ••••")
                        .font(.subheadline)
                        .fontWeight(.medium)
                } else {
                    Text("Next: \(plan.nextPurchaseAmount, format: .currency(code: "USD"))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                if let timing = plan.timing {
                    HStack(spacing: 2) {
                        Image(systemName: timing.iconName)
                        Text(timing.recommendation == "good" ? "Good" : timing.recommendation == "wait" ? "Wait" : "OK")
                    }
                    .font(.caption2)
                    .foregroundColor(timingColor(timing.recommendation))
                    .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    func timingColor(_ rec: String) -> Color {
        switch rec {
        case "good": return .green
        case "wait": return .red
        default: return .orange
        }
    }
}

struct LargeDCAPlansView: View {
    let entry: DCAPlansEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(.purple)
                Text("Investment Plans")
                    .font(.headline)
                Spacer()
                if entry.isPrivacyMode {
                    Image(systemName: "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            if entry.plans.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No active plans")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.plans.prefix(3)) { plan in
                    DCALargePlanRow(plan: plan, isPrivacyMode: entry.isPrivacyMode)
                    if plan.id != entry.plans.prefix(3).last?.id {
                        Divider()
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct DCALargePlanRow: View {
    let plan: WidgetDCAPlanData
    let isPrivacyMode: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Symbol, Price, Status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(plan.symbol)
                            .font(.headline)
                            .lineLimit(1)
                        if plan.isOverdue {
                            Text("OVERDUE")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(3)
                        }
                    }
                    Text(plan.assetName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    if !isPrivacyMode {
                        Text(plan.currentPrice, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    HStack(spacing: 2) {
                        Image(systemName: plan.dailyChangePercent >= 0 ? "arrow.up" : "arrow.down")
                        Text("\(abs(plan.dailyChangePercent), specifier: "%.1f")%")
                    }
                    .font(.caption2)
                    .foregroundColor(plan.dailyChangePercent >= 0 ? .green : .red)
                    .lineLimit(1)
                }
            }

            // Row 2: Holdings and Next Purchase
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Holdings")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isPrivacyMode {
                        Text("••••")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text(plan.currentHoldings, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Spacer()

                VStack(alignment: .center, spacing: 1) {
                    Text("Progress")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(plan.completedPurchases)/\(plan.totalPurchases)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("Next Buy")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if isPrivacyMode {
                        Text("••••")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    } else {
                        Text(plan.nextPurchaseAmount, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
            }

            // Row 3: Timing recommendation
            if let timing = plan.timing {
                HStack {
                    Image(systemName: timing.iconName)
                    Text(timing.displayText)
                    Text("-")
                    Text(timing.reason)
                        .lineLimit(1)
                }
                .font(.caption2)
                .foregroundColor(timingColor(timing.recommendation))
            }
        }
        .padding(.vertical, 4)
    }

    func timingColor(_ rec: String) -> Color {
        switch rec {
        case "good": return .green
        case "wait": return .red
        default: return .orange
        }
    }
}

struct DCAPlansWidget: Widget {
    let kind: String = "DCAPlansWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DCAPlansTimelineProvider()) { entry in
            DCAPlansWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Investment Plans")
        .description("Track your DCA investment plans and see if it's a good time to buy.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct DCAPlansWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: DCAPlansEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallDCAPlansView(entry: entry)
        case .systemMedium: MediumDCAPlansView(entry: entry)
        case .systemLarge: LargeDCAPlansView(entry: entry)
        default: SmallDCAPlansView(entry: entry)
        }
    }
}

// ============================================================================
// MARK: - STOCK NEWS WIDGET (New)
// ============================================================================

struct StockNewsEntry: TimelineEntry {
    let date: Date
    let news: [WidgetNewsData]
    let isPlaceholder: Bool

    static var placeholder: StockNewsEntry {
        StockNewsEntry(
            date: Date(),
            news: [
                WidgetNewsData(id: UUID(), symbol: "TSLA", title: "Tesla announces new Gigafactory expansion plans for 2026", publisher: "Reuters", publishedDate: Date().addingTimeInterval(-3600), link: ""),
                WidgetNewsData(id: UUID(), symbol: "NVDA", title: "NVIDIA reports record quarterly earnings driven by AI demand", publisher: "Bloomberg", publishedDate: Date().addingTimeInterval(-7200), link: ""),
                WidgetNewsData(id: UUID(), symbol: "AAPL", title: "Apple unveils new Vision Pro features at developer conference", publisher: "TechCrunch", publishedDate: Date().addingTimeInterval(-10800), link: ""),
                WidgetNewsData(id: UUID(), symbol: "QQQ", title: "Tech stocks rally as inflation concerns ease", publisher: "CNBC", publishedDate: Date().addingTimeInterval(-14400), link: ""),
            ],
            isPlaceholder: true
        )
    }
}

struct StockNewsTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StockNewsEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (StockNewsEntry) -> Void) {
        completion(loadNewsData())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StockNewsEntry>) -> Void) {
        let entry = loadNewsData()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func loadNewsData() -> StockNewsEntry {
        let news = SharedDataManager.shared.readNewsData()
        if news.isEmpty {
            return .placeholder
        }
        return StockNewsEntry(date: Date(), news: news, isPlaceholder: false)
    }
}

// Stock News Widget Views
struct SmallNewsView: View {
    let entry: StockNewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.blue)
                Text("News")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let news = entry.news.first {
                Text(news.symbol)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)

                Text(news.title)
                    .font(.caption)
                    .lineLimit(3)

                Spacer()

                Text(news.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("No recent news")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct MediumNewsView: View {
    let entry: StockNewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.blue)
                Text("Stock News")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            if entry.news.isEmpty {
                Spacer()
                Text("No recent news")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.news.prefix(3)) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.symbol)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .frame(width: 45, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.caption)
                                .lineLimit(2)
                            Text("\(item.publisher) · \(item.timeAgo)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct LargeNewsView: View {
    let entry: StockNewsEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "newspaper.fill")
                    .foregroundColor(.blue)
                Text("Stock News")
                    .font(.headline)
                Spacer()
                Text("Your Holdings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            if entry.news.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "newspaper")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No recent news")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                ForEach(entry.news.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.symbol)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)

                            Spacer()

                            Text(item.timeAgo)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Text(item.title)
                            .font(.subheadline)
                            .lineLimit(2)

                        Text(item.publisher)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)

                    if item.id != entry.news.prefix(5).last?.id {
                        Divider()
                    }
                }
            }

            Spacer()
        }
        .padding()
        .containerBackground(.fill, for: .widget)
    }
}

struct StockNewsWidget: Widget {
    let kind: String = "StockNewsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StockNewsTimelineProvider()) { entry in
            StockNewsWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Stock News")
        .description("Recent news about your portfolio holdings.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct StockNewsWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: StockNewsEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallNewsView(entry: entry)
        case .systemMedium: MediumNewsView(entry: entry)
        case .systemLarge: LargeNewsView(entry: entry)
        default: SmallNewsView(entry: entry)
        }
    }
}

// ============================================================================
// MARK: - WIDGET BUNDLE
// ============================================================================

@main
struct AssetMonitorWidgetBundle: WidgetBundle {
    var body: some Widget {
        AssetMonitorWidget()
        DCAPlansWidget()
        StockNewsWidget()
    }
}

// ============================================================================
// MARK: - SHARED DATA MODELS (duplicated for widget target)
// ============================================================================

// Note: These are duplicated from SharedDataManager because the widget
// extension needs its own copy. In a real project, you'd put these in a
// shared framework target.

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
    let currentHoldings: Double
    let currentShares: Double
    let currentPrice: Double
    let dailyChangePercent: Double
    let totalPlanAmount: Double
    let completedPurchases: Int
    let totalPurchases: Int
    let nextPurchaseAmount: Double
    let nextPurchaseDate: Date?
    let isOverdue: Bool
    var timing: WidgetTimingData?
}

struct WidgetTimingData: Codable {
    let recommendation: String
    let reason: String
    let percentFromAverage: Double?

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

// Simplified SharedDataManager for widget extension
class SharedDataManager {
    static let shared = SharedDataManager()
    private let suiteName = "group.JinWookShin.AssetMonitor"
    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    var isPrivacyModeEnabled: Bool {
        defaults?.bool(forKey: "privacyMode") ?? false
    }

    func readWidgetData() -> (totalValue: Double, dailyChange: Double, dailyChangePercent: Double, holdings: [WidgetHoldingData], lastUpdated: Date?) {
        guard let defaults = defaults else { return (0, 0, 0, [], nil) }
        let totalValue = defaults.double(forKey: "totalValue")
        let dailyChange = defaults.double(forKey: "dailyChange")
        let dailyChangePercent = defaults.double(forKey: "dailyChangePercent")
        let lastUpdated = defaults.object(forKey: "lastUpdated") as? Date
        var holdings: [WidgetHoldingData] = []
        if let data = defaults.data(forKey: "topHoldings"),
           let decoded = try? JSONDecoder().decode([WidgetHoldingData].self, from: data) {
            holdings = decoded
        }
        return (totalValue, dailyChange, dailyChangePercent, holdings, lastUpdated)
    }

    func readDCAPlansData() -> [WidgetDCAPlanData] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "dcaPlans"),
              let decoded = try? JSONDecoder().decode([WidgetDCAPlanData].self, from: data) else { return [] }
        return decoded
    }

    func readNewsData() -> [WidgetNewsData] {
        guard let defaults = defaults,
              let data = defaults.data(forKey: "stockNews"),
              let decoded = try? JSONDecoder().decode([WidgetNewsData].self, from: data) else { return [] }
        return decoded
    }
}

// ============================================================================
// MARK: - PREVIEWS
// ============================================================================

#Preview("Portfolio Small", as: .systemSmall) {
    AssetMonitorWidget()
} timeline: {
    PortfolioEntry.placeholder
}

#Preview("DCA Plans Medium", as: .systemMedium) {
    DCAPlansWidget()
} timeline: {
    DCAPlansEntry.placeholder
}

#Preview("DCA Plans Large", as: .systemLarge) {
    DCAPlansWidget()
} timeline: {
    DCAPlansEntry.placeholder
}

#Preview("News Medium", as: .systemMedium) {
    StockNewsWidget()
} timeline: {
    StockNewsEntry.placeholder
}

#Preview("News Large", as: .systemLarge) {
    StockNewsWidget()
} timeline: {
    StockNewsEntry.placeholder
}
