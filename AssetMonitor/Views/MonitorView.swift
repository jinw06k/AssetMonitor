import SwiftUI
import Charts

struct MonitorView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    enum ListMode: String, CaseIterable {
        case holdings = "Holdings"
        case watchlist = "Watchlist"
    }

    @State private var listMode: ListMode = .holdings
    @State private var selectedSymbol: String?
    @State private var showingAddSheet = false

    private var holdingsSymbols: [(symbol: String, name: String, price: Double?, changePercent: Double)] {
        databaseService.assets
            .filter { $0.type == .stock || $0.type == .etf || $0.type == .treasury }
            .sorted { $0.totalValue > $1.totalValue }
            .map { ($0.symbol, $0.name, $0.currentPrice, $0.dailyChangePercent) }
    }

    private var watchlistSymbols: [(symbol: String, name: String, price: Double?, changePercent: Double)] {
        databaseService.watchlistItems.map { ($0.symbol, $0.name, $0.currentPrice, $0.dailyChangePercent) }
    }

    private var displayedSymbols: [(symbol: String, name: String, price: Double?, changePercent: Double)] {
        listMode == .holdings ? holdingsSymbols : watchlistSymbols
    }

    var body: some View {
        HSplitView {
            // Left panel - Symbol list
            VStack(spacing: 0) {
                // Header
                HStack {
                    Picker("Mode", selection: $listMode) {
                        ForEach(ListMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if listMode == .watchlist {
                        Button(action: { showingAddSheet = true }) {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(Theme.Spacing.md)

                Divider()

                // Symbol list
                if displayedSymbols.isEmpty {
                    VStack(spacing: Theme.Spacing.md) {
                        Image(systemName: listMode == .holdings ? "chart.line.uptrend.xyaxis" : "star")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text(listMode == .holdings ? "No tradable holdings" : "No watchlist items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if listMode == .watchlist {
                            Button("Add Symbol") { showingAddSheet = true }
                                .buttonStyle(.bordered)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedSymbol) {
                        ForEach(displayedSymbols, id: \.symbol) { item in
                            SymbolListRow(
                                symbol: item.symbol,
                                name: item.name,
                                price: item.price,
                                changePercent: item.changePercent
                            )
                            .tag(item.symbol)
                            .contextMenu {
                                if listMode == .watchlist {
                                    Button(role: .destructive) {
                                        if let watchItem = databaseService.watchlistItems.first(where: { $0.symbol == item.symbol }) {
                                            viewModel.removeFromWatchlist(watchItem)
                                        }
                                    } label: {
                                        Label("Remove from Watchlist", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)

            // Right panel - Chart detail
            if let symbol = selectedSymbol {
                StockChartDetailView(symbol: symbol)
            } else {
                VStack(spacing: Theme.Spacing.lg) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("Select a symbol to view chart")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddWatchlistSheet()
        }
        .task {
            await viewModel.refreshWatchlistPrices()
            // Auto-select first symbol if none selected
            if selectedSymbol == nil, let first = displayedSymbols.first {
                selectedSymbol = first.symbol
            }
        }
        .onChange(of: listMode) { _, _ in
            // Reset selection when switching modes
            selectedSymbol = displayedSymbols.first?.symbol
        }
    }
}

// MARK: - Symbol List Row

struct SymbolListRow: View {
    let symbol: String
    let name: String
    let price: Double?
    let changePercent: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(symbol)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if let price = price {
                    Text(price, format: .currency(code: "USD"))
                        .font(.caption)
                        .fontWeight(.medium)
                    ChangeIndicator(value: changePercent, format: .percent, font: .caption2)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(height: 12)
                }
            }
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

// MARK: - Stock Chart Detail View

struct StockChartDetailView: View {
    let symbol: String

    @State private var selectedRange: YahooFinanceService.ChartRange = .oneMonth
    @State private var chartData: [HistoricalDataPoint] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var hoveredPoint: HistoricalDataPoint?
    @State private var currentQuote: StockQuote?

    private var hoveredPriceChange: Double {
        guard let hovered = hoveredPoint, let first = chartData.first else { return 0 }
        return hovered.close - first.close
    }

    private var hoveredPercentChange: Double {
        guard let hovered = hoveredPoint, let first = chartData.first, first.close > 0 else { return 0 }
        return ((hovered.close - first.close) / first.close) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
            // Header with price
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(symbol)
                        .font(.title2)
                        .fontWeight(.bold)
                    if let quote = currentQuote {
                        Text(quote.name)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if let quote = currentQuote {
                    HStack(spacing: Theme.Spacing.md) {
                        if let hovered = hoveredPoint {
                            Text(hovered.close, format: .currency(code: "USD"))
                                .font(.title)
                                .fontWeight(.semibold)
                            HStack(spacing: Theme.Spacing.xs) {
                                ChangeIndicator(value: hoveredPriceChange, format: .currency, font: .subheadline)
                                Text("(\(hoveredPercentChange >= 0 ? "+" : "")\(String(format: "%.2f%%", hoveredPercentChange)))")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.StatusColors.changeColor(for: hoveredPercentChange))
                            }
                            Text(hovered.date, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(quote.price, format: .currency(code: "USD"))
                                .font(.title)
                                .fontWeight(.semibold)
                            if !chartData.isEmpty {
                                HStack(spacing: Theme.Spacing.xs) {
                                    ChangeIndicator(value: chartPriceChange, format: .currency, font: .subheadline)
                                    Text("(\(chartGrowthPercent >= 0 ? "+" : "")\(String(format: "%.2f%%", chartGrowthPercent)))")
                                        .font(.subheadline)
                                        .foregroundColor(Theme.StatusColors.changeColor(for: chartGrowthPercent))
                                }
                            }
                        }
                    }
                } else if isLoading {
                    LoadingPlaceholder(height: 32)
                        .frame(width: 150)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.lg)

            // Time range picker
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(YahooFinanceService.ChartRange.allCases, id: \.self) { range in
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
            .padding(.horizontal, Theme.Spacing.lg)

            // Chart
            if isLoading && chartData.isEmpty {
                VStack {
                    ProgressView()
                    Text("Loading chart...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, chartData.isEmpty {
                VStack(spacing: Theme.Spacing.md) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(Theme.StatusColors.warning)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Retry") {
                        Task { await loadData() }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !chartData.isEmpty {
                ZStack {
                    chartView
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .padding(Theme.Spacing.sm)
                            .background(.ultraThinMaterial)
                            .cornerRadius(Theme.CornerRadius.medium)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            } else {
                ContentUnavailableView(
                    "No Chart Data",
                    systemImage: "chart.xyaxis.line",
                    description: Text("No data available for this symbol")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Spacer()
        }
        .task(id: symbol) {
            await loadData()
        }
        .onChange(of: selectedRange) { _, _ in
            Task { await loadChartData() }
        }
    }

    private var chartPriceChange: Double {
        guard let first = chartData.first, let last = chartData.last else { return 0 }
        return last.close - first.close
    }

    private var chartGrowthPercent: Double {
        guard let first = chartData.first, let last = chartData.last, first.close > 0 else { return 0 }
        return ((last.close - first.close) / first.close) * 100
    }

    @ViewBuilder
    private var chartView: some View {
        Chart(chartData) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Theme.StatusColors.changeColor(for: chartGrowthPercent).opacity(0.3),
                        Theme.StatusColors.changeColor(for: chartGrowthPercent).opacity(0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.close)
            )
            .foregroundStyle(Theme.StatusColors.changeColor(for: chartGrowthPercent))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        if selectedRange == .oneDay || selectedRange == .fiveDays {
                            Text(date, format: .dateTime.hour().minute())
                        } else {
                            Text(date, format: .dateTime.month(.abbreviated).day())
                        }
                    }
                }
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
                                    hoveredPoint = chartData.min(by: {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    })
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
        .frame(minHeight: 300)
    }

    private func loadData() async {
        // Load quote and chart in parallel
        async let quoteTask: () = loadQuote()
        async let chartTask: () = loadChartData()
        _ = await (quoteTask, chartTask)
    }

    private func loadQuote() async {
        do {
            currentQuote = try await YahooFinanceService.shared.fetchQuote(symbol: symbol)
        } catch {
            // Non-fatal, chart can still show
        }
    }

    private func loadChartData() async {
        isLoading = true
        errorMessage = nil

        do {
            chartData = try await YahooFinanceService.shared.fetchChartData(
                symbol: symbol,
                chartRange: selectedRange
            )
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Add Watchlist Sheet

struct AddWatchlistSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    @State private var symbol = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add to Watchlist")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                TextField("Symbol (e.g., AAPL)", text: $symbol)
                    .textFieldStyle(.roundedBorder)
                    .textCase(.uppercase)
                    .onSubmit { lookupSymbol() }

                TextField("Name (auto-filled on lookup)", text: $name)
                    .textFieldStyle(.roundedBorder)

                if isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Looking up symbol...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(Theme.StatusColors.negative)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("Lookup") { lookupSymbol() }
                    .buttonStyle(.bordered)
                    .disabled(symbol.isEmpty || isLoading)
                Spacer()
                Button("Add") { addSymbol() }
                    .buttonStyle(.borderedProminent)
                    .disabled(symbol.isEmpty || isLoading)
                    .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 350, height: 280)
    }

    private func lookupSymbol() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let quote = try await YahooFinanceService.shared.fetchQuote(symbol: symbol.uppercased())
                name = quote.name
            } catch {
                errorMessage = "Could not find symbol '\(symbol.uppercased())'"
            }
            isLoading = false
        }
    }

    private func addSymbol() {
        let upperSymbol = symbol.uppercased()

        // Check for duplicates
        if DatabaseService.shared.watchlistItems.contains(where: { $0.symbol == upperSymbol }) {
            errorMessage = "'\(upperSymbol)' is already in your watchlist"
            return
        }

        let finalName = name.isEmpty ? upperSymbol : name
        viewModel.addToWatchlist(symbol: upperSymbol, name: finalName)
        dismiss()
    }
}

#Preview {
    MonitorView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
