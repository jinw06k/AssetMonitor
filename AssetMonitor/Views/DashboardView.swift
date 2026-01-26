import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.xl) {
                // Portfolio Summary Cards
                HStack(spacing: Theme.Spacing.lg) {
                    SummaryCard(
                        title: "Total Value",
                        value: viewModel.totalPortfolioValue,
                        format: .currency,
                        icon: "dollarsign.circle.fill",
                        color: .accentColor
                    )

                    SummaryCard(
                        title: "Today's Change",
                        value: viewModel.dailyChange,
                        format: .currency,
                        change: viewModel.dailyChangePercent,
                        icon: "chart.line.uptrend.xyaxis",
                        color: Theme.StatusColors.changeColor(for: viewModel.dailyChange)
                    )

                    SummaryCard(
                        title: "Total Return",
                        value: viewModel.totalGainLoss,
                        format: .currency,
                        change: viewModel.totalGainLossPercent,
                        icon: "arrow.up.right",
                        color: Theme.StatusColors.changeColor(for: viewModel.totalGainLoss)
                    )

                    SummaryCard(
                        title: "Holdings",
                        value: Double(databaseService.assets.count),
                        format: .number,
                        icon: "chart.pie.fill",
                        color: .accentColor
                    )
                }
                .opacity(isLoaded ? 1 : 0)
                .offset(y: isLoaded ? 0 : 10)

                HStack(spacing: Theme.Spacing.xl) {
                    // Allocation Chart with hover
                    InteractivePieChart(
                        data: viewModel.allocationData,
                        totalValue: viewModel.totalPortfolioValue
                    )
                    .cardStyle()

                    // Type Allocation with hover details
                    VStack(alignment: .leading) {
                        Text("Asset Types")
                            .font(.headline)

                        if viewModel.typeAllocationData.isEmpty {
                            ContentUnavailableView(
                                "No Holdings",
                                systemImage: "building.columns",
                                description: Text("Add assets to see breakdown")
                            )
                            .frame(height: 250)
                        } else {
                            VStack(spacing: Theme.Spacing.md) {
                                ForEach(viewModel.typeAllocationData) { item in
                                    AssetTypeRow(
                                        item: item,
                                        assets: databaseService.assets.filter { $0.type == item.type },
                                        totalTypeValue: item.value
                                    )
                                }
                            }
                            .frame(height: 250)
                        }
                    }
                    .cardStyle()
                }
                .opacity(isLoaded ? 1 : 0)
                .offset(y: isLoaded ? 0 : 15)

                // Portfolio Growth & Top Holdings side by side
                HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                    // Portfolio Growth Chart (compact)
                    PortfolioGrowthChartCompact()
                        .cardStyle()
                        .frame(maxWidth: .infinity)

                    // Top Holdings (compact)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        SectionHeader(
                            title: "Top Holdings",
                            action: { viewModel.selectedTab = .assets },
                            actionLabel: "View All"
                        )

                        if databaseService.assets.isEmpty {
                            VStack(spacing: Theme.Spacing.sm) {
                                Image(systemName: "tray")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No holdings yet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                        } else {
                            ForEach(Array(databaseService.assets.sorted { $0.totalValue > $1.totalValue }.prefix(4).enumerated()), id: \.element.id) { index, asset in
                                CompactHoldingRow(asset: asset, totalValue: viewModel.totalPortfolioValue)
                                    .opacity(isLoaded ? 1 : 0)
                                    .offset(y: isLoaded ? 0 : 10)
                                    .animation(Theme.Animation.standard.delay(Double(index) * 0.05), value: isLoaded)
                            }
                        }
                    }
                    .cardStyle()
                    .frame(maxWidth: .infinity)
                }
                .opacity(isLoaded ? 1 : 0)
                .offset(y: isLoaded ? 0 : 18)

                // Active Plans Alert
                if !viewModel.overduePlans.isEmpty {
                    OverduePlansAlert(plans: viewModel.overduePlans) {
                        viewModel.selectedTab = .plans
                    }
                    .opacity(isLoaded ? 1 : 0)
                    .offset(y: isLoaded ? 0 : 25)
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(Theme.Animation.smooth) {
                isLoaded = true
            }
        }
    }
}

// MARK: - Overdue Plans Alert

struct OverduePlansAlert: View {
    let plans: [InvestmentPlan]
    let onViewPlans: () -> Void
    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.StatusColors.warning)
                    .font(.title3)
                Text("Overdue Investment Plans")
                    .font(.headline)
                Spacer()
                Text("\(plans.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.StatusColors.warning)
                    .foregroundColor(.white)
                    .cornerRadius(Theme.CornerRadius.small)
            }

            ForEach(plans) { plan in
                if let asset = databaseService.getAsset(byId: plan.assetId) {
                    HStack {
                        Circle()
                            .fill(Theme.AssetColors.color(for: asset.type))
                            .frame(width: 8, height: 8)
                        Text(asset.symbol)
                            .fontWeight(.medium)
                        Text("Purchase #\(plan.completedPurchases + 1) overdue")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(plan.amountPerPurchase, format: .currency(code: "USD"))
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }

            Button("View Plans") {
                onViewPlans()
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.StatusColors.warning)
        }
        .padding()
        .background(Theme.StatusColors.warning.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(Theme.StatusColors.warning.opacity(0.3), lineWidth: 1)
        )
        .cornerRadius(Theme.CornerRadius.large)
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let title: String
    let value: Double
    let format: ValueFormat
    var change: Double? = nil
    let icon: String
    let color: Color

    @State private var isHovered = false

    enum ValueFormat {
        case currency
        case number
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: Theme.IconSize.medium))
                Text(title)
                    .foregroundColor(.secondary)
            }
            .font(.caption)

            switch format {
            case .currency:
                Text(value, format: .currency(code: "USD"))
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            case .number:
                Text("\(Int(value))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .contentTransition(.numericText())
            }

            if let change = change {
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: change >= 0 ? "arrow.up" : "arrow.down")
                    Text(String(format: "%.2f%%", abs(change)))
                }
                .font(.caption)
                .foregroundColor(Theme.StatusColors.changeColor(for: change))
            } else {
                // Placeholder to maintain consistent height
                Text(" ")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(isHovered ? color.opacity(0.3) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Theme.Animation.quick, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Holding Row

struct HoldingRow: View {
    let asset: Asset
    let totalValue: Double
    @State private var isHovered = false

    var allocation: Double {
        guard totalValue > 0 else { return 0 }
        return (asset.totalValue / totalValue) * 100
    }

    var body: some View {
        HStack {
            // Asset type indicator
            Circle()
                .fill(Theme.AssetColors.color(for: asset.type))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(asset.symbol)
                        .fontWeight(.semibold)
                    Image(systemName: asset.type.iconName)
                        .font(.caption)
                        .foregroundColor(Theme.AssetColors.color(for: asset.type))
                }
                Text(asset.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if let price = asset.currentPrice {
                    Text(price, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                        .contentTransition(.numericText())
                }
                HStack(spacing: Theme.Spacing.xxs) {
                    Image(systemName: asset.dailyChangePercent >= 0 ? "arrow.up" : "arrow.down")
                        .font(.caption2)
                    Text(String(format: "%@%.2f%%", asset.dailyChangePercent >= 0 ? "+" : "", asset.dailyChangePercent))
                }
                .font(.caption)
                .foregroundColor(Theme.StatusColors.changeColor(for: asset.dailyChangePercent))
            }

            Divider()
                .frame(height: 30)
                .padding(.horizontal, Theme.Spacing.md)

            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(asset.totalValue, format: .currency(code: "USD"))
                    .fontWeight(.medium)
                    .contentTransition(.numericText())
                Text(String(format: "%.1f%%", allocation))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(isHovered ? Theme.Colors.overlay(opacity: 0.05) : Color.clear)
        .cornerRadius(Theme.CornerRadius.medium)
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Asset Type Row with Hover Popover

struct AssetTypeRow: View {
    let item: AllocationItem
    let assets: [Asset]
    let totalTypeValue: Double

    @State private var isHovering = false
    @State private var animatedWidth: CGFloat = 0

    private var typeColor: Color {
        Theme.AssetColors.color(for: item.type)
    }

    var body: some View {
        HStack {
            HStack(spacing: Theme.Spacing.xs) {
                Circle()
                    .fill(typeColor)
                    .frame(width: 8, height: 8)
                Text(item.name)
                    .fontWeight(.medium)
            }
            .frame(width: 70, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 24)

                    RoundedRectangle(cornerRadius: Theme.CornerRadius.small)
                        .fill(
                            LinearGradient(
                                colors: [typeColor, typeColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(animatedWidth, 20), height: 24)
                        .onAppear {
                            withAnimation(Theme.Animation.smooth.delay(0.1)) {
                                animatedWidth = geometry.size.width * CGFloat(item.percentage / 100)
                            }
                        }
                }
            }
            .frame(height: 24)

            Text(item.value, format: .currency(code: "USD"))
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 85, alignment: .trailing)

            Text(String(format: "%.1f%%", item.percentage))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(isHovering ? typeColor.opacity(0.08) : Color.clear)
        .cornerRadius(Theme.CornerRadius.medium)
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovering = hovering
            }
        }
        .popover(isPresented: $isHovering, arrowEdge: .trailing) {
            AssetTypePopover(type: item.type, assets: assets, totalTypeValue: totalTypeValue)
        }
    }
}

// MARK: - Asset Type Popover Content

struct AssetTypePopover: View {
    let type: AssetType
    let assets: [Asset]
    let totalTypeValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(type.displayName) Breakdown")
                .font(.headline)

            Divider()

            if type == .cd {
                // CD-specific view with maturity dates
                if assets.isEmpty {
                    Text("No CDs")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(assets.sorted { ($0.cdMaturityDate ?? Date.distantFuture) < ($1.cdMaturityDate ?? Date.distantFuture) }) { cd in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(cd.name)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(cd.cdCurrentValue ?? cd.totalCost, format: .currency(code: "USD"))
                            }

                            HStack {
                                if let rate = cd.cdInterestRate {
                                    Text("APY: \(rate, specifier: "%.2f")%")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }

                                Spacer()

                                if let maturity = cd.cdMaturityDate {
                                    let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: maturity).day ?? 0
                                    if daysRemaining > 0 {
                                        Text("Matures: \(maturity, style: .date) (\(daysRemaining) days)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Matured!")
                                            .font(.caption)
                                            .foregroundColor(Theme.StatusColors.warning)
                                    }
                                }
                            }

                            if totalTypeValue > 0 {
                                let percentage = ((cd.cdCurrentValue ?? cd.totalCost) / totalTypeValue) * 100
                                Text("\(percentage, specifier: "%.1f")% of CDs")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        if cd.id != assets.last?.id {
                            Divider()
                        }
                    }
                }
            } else if type == .cash {
                // Cash summary
                if assets.isEmpty {
                    Text("No cash accounts")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(assets) { cash in
                        HStack {
                            Text(cash.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text(cash.totalValue, format: .currency(code: "USD"))
                        }
                    }
                }
            } else {
                // Stocks/ETFs breakdown
                if assets.isEmpty {
                    Text("No \(type.displayName.lowercased())s")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(assets.sorted { $0.totalValue > $1.totalValue }) { asset in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(asset.symbol)
                                    .fontWeight(.medium)
                                Text(asset.name)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            VStack(alignment: .trailing) {
                                Text(asset.totalValue, format: .currency(code: "USD"))
                                if totalTypeValue > 0 {
                                    let percentage = (asset.totalValue / totalTypeValue) * 100
                                    Text("\(percentage, specifier: "%.1f")%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Divider()

            HStack {
                Text("Total")
                    .fontWeight(.bold)
                Spacer()
                Text(totalTypeValue, format: .currency(code: "USD"))
                    .fontWeight(.bold)
            }
        }
        .padding()
        .frame(minWidth: 280, maxWidth: 350)
    }
}

// MARK: - Interactive Pie Chart with Hover

struct InteractivePieChart: View {
    let data: [AllocationItem]
    let totalValue: Double

    @State private var hoveredItem: AllocationItem?
    @State private var mouseLocation: CGPoint = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Asset Allocation")
                .font(.headline)

            if data.isEmpty {
                ContentUnavailableView(
                    "No Holdings",
                    systemImage: "chart.pie",
                    description: Text("Add assets to see allocation")
                )
                .frame(height: 250)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Value", item.value),
                        innerRadius: .ratio(hoveredItem?.id == item.id ? 0.5 : 0.55),
                        outerRadius: .ratio(hoveredItem?.id == item.id ? 1.0 : 0.95),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Asset", item.name))
                    .cornerRadius(4)
                    .opacity(hoveredItem == nil || hoveredItem?.id == item.id ? 1.0 : 0.5)
                }
                .chartForegroundStyleScale(domain: data.map { $0.name }, range: data.map { Theme.AssetColors.color(for: $0.type) })
                .chartLegend(.hidden)
                .chartBackground { _ in
                    // Center content showing hovered item or total
                    VStack(spacing: Theme.Spacing.xs) {
                        if let hovered = hoveredItem {
                            Circle()
                                .fill(Theme.AssetColors.color(for: hovered.type).opacity(0.2))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Image(systemName: hovered.type.iconName)
                                        .foregroundColor(Theme.AssetColors.color(for: hovered.type))
                                )
                            Text(hovered.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            Text(hovered.value, format: .currency(code: "USD"))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(String(format: "%.1f%%", hovered.percentage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Total")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(totalValue, format: .currency(code: "USD"))
                                .font(.title3)
                                .fontWeight(.bold)
                        }
                    }
                    .animation(Theme.Animation.quick, value: hoveredItem?.id)
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    updateHoveredItem(at: location, in: geometry.size)
                                case .ended:
                                    withAnimation(Theme.Animation.quick) {
                                        hoveredItem = nil
                                    }
                                }
                            }
                    }
                }
                .frame(height: 250)

                // Legend (highlights when corresponding slice is hovered)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: Theme.Spacing.sm) {
                    ForEach(data) { item in
                        HStack(spacing: Theme.Spacing.xs) {
                            Circle()
                                .fill(Theme.AssetColors.color(for: item.type))
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", item.percentage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, Theme.Spacing.xxs)
                        .padding(.horizontal, Theme.Spacing.xs)
                        .background(hoveredItem?.id == item.id ? Theme.AssetColors.color(for: item.type).opacity(0.1) : Color.clear)
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                }
            }
        }
    }

    private func updateHoveredItem(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let radius = min(size.width, size.height) / 2

        // Check if within the donut area (between inner and outer radius)
        let innerRadius = radius * 0.5
        let outerRadius = radius * 1.0

        guard distance >= innerRadius && distance <= outerRadius else {
            withAnimation(Theme.Animation.quick) {
                hoveredItem = nil
            }
            return
        }

        // Calculate angle from center (0 = top, clockwise)
        var angle = atan2(dx, -dy) * 180 / .pi // Convert to degrees, 0 at top
        if angle < 0 { angle += 360 }

        // Find which slice this angle falls into
        let total = data.reduce(0) { $0 + $1.value }
        guard total > 0 else { return }

        var cumulativeAngle: Double = 0
        for item in data {
            let sliceAngle = (item.value / total) * 360
            if angle >= cumulativeAngle && angle < cumulativeAngle + sliceAngle {
                if hoveredItem?.id != item.id {
                    withAnimation(Theme.Animation.quick) {
                        hoveredItem = item
                    }
                }
                return
            }
            cumulativeAngle += sliceAngle
        }

        // Edge case: angle is exactly 360 (same as 0)
        if let firstItem = data.first, hoveredItem?.id != firstItem.id {
            withAnimation(Theme.Animation.quick) {
                hoveredItem = firstItem
            }
        }
    }
}

// MARK: - Pie Slice Shape (kept for potential future use)

struct PieSliceShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Portfolio Growth Chart

struct PortfolioGrowthChart: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var selectedRange: TimeRange = .month
    @State private var hoveredPoint: PortfolioDataPoint?

    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"
        case year = "1Y"
        case all = "All"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            case .year: return 365
            case .all: return 3650
            }
        }
    }

    var portfolioData: [PortfolioDataPoint] {
        generatePortfolioHistory()
    }

    var filteredData: [PortfolioDataPoint] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return portfolioData.filter { $0.date >= cutoffDate }
    }

    var growthPercent: Double {
        guard let first = filteredData.first, let last = filteredData.last, first.value > 0 else { return 0 }
        return ((last.value - first.value) / first.value) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Portfolio Growth")
                        .font(.headline)
                    if let hovered = hoveredPoint {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(hovered.value, format: .currency(code: "USD"))
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(hovered.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack(spacing: Theme.Spacing.sm) {
                            Text(viewModel.totalPortfolioValue, format: .currency(code: "USD"))
                                .font(.title3)
                                .fontWeight(.semibold)
                            ChangeIndicator(value: growthPercent, format: .percent, font: .subheadline)
                        }
                    }
                }

                Spacer()

                // Time range picker
                HStack(spacing: Theme.Spacing.xs) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            withAnimation(Theme.Animation.quick) {
                                selectedRange = range
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .fontWeight(selectedRange == range ? .semibold : .regular)
                        .foregroundColor(selectedRange == range ? .primary : .secondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(selectedRange == range ? Theme.Colors.overlay(opacity: 0.1) : Color.clear)
                        .cornerRadius(Theme.CornerRadius.small)
                    }
                }
            }

            if filteredData.isEmpty {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Add transactions to see growth")
                )
                .frame(height: 200)
            } else {
                Chart(filteredData) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Theme.StatusColors.changeColor(for: growthPercent).opacity(0.3),
                                Theme.StatusColors.changeColor(for: growthPercent).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Theme.StatusColors.changeColor(for: growthPercent))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        AxisValueLabel {
                            if let doubleValue = value.as(Double.self) {
                                Text(doubleValue.formatted(.currency(code: "USD").notation(.compactName)))
                            }
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        let x = value.location.x
                                        if let date: Date = proxy.value(atX: x) {
                                            hoveredPoint = filteredData.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                        }
                                    }
                                    .onEnded { _ in
                                        hoveredPoint = nil
                                    }
                            )
                            .onHover { hovering in
                                if !hovering {
                                    hoveredPoint = nil
                                }
                            }
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private func generatePortfolioHistory() -> [PortfolioDataPoint] {
        // Generate simulated historical data based on transactions
        let transactions = databaseService.transactions.sorted { $0.date < $1.date }
        guard !transactions.isEmpty else {
            // If no transactions, return current value as single point
            if viewModel.totalPortfolioValue > 0 {
                return [PortfolioDataPoint(date: Date(), value: viewModel.totalPortfolioValue)]
            }
            return []
        }

        var dataPoints: [PortfolioDataPoint] = []
        let startDate = transactions.first?.date ?? Date()
        let calendar = Calendar.current

        // Calculate cumulative value at each transaction date
        var cumulativeValue: Double = 0
        var transactionIndex = 0

        // Generate daily points
        var currentDate = startDate
        while currentDate <= Date() {
            // Add any transactions on or before this date
            while transactionIndex < transactions.count &&
                  transactions[transactionIndex].date <= currentDate {
                let tx = transactions[transactionIndex]
                switch tx.type {
                case .buy, .deposit:
                    cumulativeValue += tx.totalAmount
                case .sell, .withdrawal:
                    cumulativeValue -= tx.totalAmount
                case .dividend, .interest:
                    cumulativeValue += tx.totalAmount
                }
                transactionIndex += 1
            }

            // Add some market variation for realistic look (simplified simulation)
            let variation = 1.0 + (Double.random(in: -0.02...0.02))
            let adjustedValue = max(0, cumulativeValue * variation)

            dataPoints.append(PortfolioDataPoint(date: currentDate, value: adjustedValue))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }

        // Ensure last point is current actual value
        if let last = dataPoints.last {
            dataPoints[dataPoints.count - 1] = PortfolioDataPoint(date: last.date, value: viewModel.totalPortfolioValue)
        }

        return dataPoints
    }
}

// MARK: - Portfolio Data Point

struct PortfolioDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

// MARK: - Compact Portfolio Growth Chart

struct PortfolioGrowthChartCompact: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var selectedRange: TimeRange = .month

    enum TimeRange: String, CaseIterable {
        case week = "1W"
        case month = "1M"
        case threeMonths = "3M"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }

    var portfolioData: [PortfolioDataPoint] {
        generatePortfolioHistory()
    }

    var filteredData: [PortfolioDataPoint] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedRange.days, to: Date()) ?? Date()
        return portfolioData.filter { $0.date >= cutoffDate }
    }

    var growthPercent: Double {
        guard let first = filteredData.first, let last = filteredData.last, first.value > 0 else { return 0 }
        return ((last.value - first.value) / first.value) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Growth")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                // Time range picker (compact)
                HStack(spacing: 2) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Button(range.rawValue) {
                            withAnimation(Theme.Animation.quick) {
                                selectedRange = range
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption2)
                        .fontWeight(selectedRange == range ? .semibold : .regular)
                        .foregroundColor(selectedRange == range ? .primary : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(selectedRange == range ? Theme.Colors.overlay(opacity: 0.1) : Color.clear)
                        .cornerRadius(4)
                    }
                }
            }

            HStack(spacing: Theme.Spacing.xs) {
                Text(viewModel.totalPortfolioValue, format: .currency(code: "USD"))
                    .font(.title3)
                    .fontWeight(.bold)
                ChangeIndicator(value: growthPercent, format: .percent, font: .caption)
            }

            if filteredData.isEmpty {
                VStack {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No data")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                Chart(filteredData) { point in
                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Theme.StatusColors.changeColor(for: growthPercent).opacity(0.3),
                                Theme.StatusColors.changeColor(for: growthPercent).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(Theme.StatusColors.changeColor(for: growthPercent))
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 100)
            }
        }
    }

    private func generatePortfolioHistory() -> [PortfolioDataPoint] {
        let transactions = databaseService.transactions.sorted { $0.date < $1.date }
        guard !transactions.isEmpty else {
            if viewModel.totalPortfolioValue > 0 {
                return [PortfolioDataPoint(date: Date(), value: viewModel.totalPortfolioValue)]
            }
            return []
        }

        var dataPoints: [PortfolioDataPoint] = []
        let startDate = transactions.first?.date ?? Date()
        let calendar = Calendar.current

        var cumulativeValue: Double = 0
        var transactionIndex = 0

        var currentDate = startDate
        while currentDate <= Date() {
            while transactionIndex < transactions.count &&
                  transactions[transactionIndex].date <= currentDate {
                let tx = transactions[transactionIndex]
                switch tx.type {
                case .buy, .deposit:
                    cumulativeValue += tx.totalAmount
                case .sell, .withdrawal:
                    cumulativeValue -= tx.totalAmount
                case .dividend, .interest:
                    cumulativeValue += tx.totalAmount
                }
                transactionIndex += 1
            }

            let variation = 1.0 + (Double.random(in: -0.02...0.02))
            let adjustedValue = max(0, cumulativeValue * variation)

            dataPoints.append(PortfolioDataPoint(date: currentDate, value: adjustedValue))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate.addingTimeInterval(86400)
        }

        if let last = dataPoints.last {
            dataPoints[dataPoints.count - 1] = PortfolioDataPoint(date: last.date, value: viewModel.totalPortfolioValue)
        }

        return dataPoints
    }
}

// MARK: - Compact Holding Row

struct CompactHoldingRow: View {
    let asset: Asset
    let totalValue: Double
    @State private var isHovered = false

    var allocation: Double {
        guard totalValue > 0 else { return 0 }
        return (asset.totalValue / totalValue) * 100
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Circle()
                .fill(Theme.AssetColors.color(for: asset.type))
                .frame(width: 6, height: 6)

            Text(asset.symbol)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 50, alignment: .leading)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(asset.totalValue, format: .currency(code: "USD"))
                    .font(.caption)
                    .fontWeight(.medium)
                HStack(spacing: 2) {
                    Image(systemName: asset.dailyChangePercent >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8))
                    Text(String(format: "%.1f%%", abs(asset.dailyChangePercent)))
                        .font(.caption2)
                }
                .foregroundColor(Theme.StatusColors.changeColor(for: asset.dailyChangePercent))
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .padding(.horizontal, Theme.Spacing.xs)
        .background(isHovered ? Theme.Colors.overlay(opacity: 0.05) : Color.clear)
        .cornerRadius(Theme.CornerRadius.small)
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
