import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var autoRefreshTimer: Timer?
    @AppStorage("refresh_interval") private var refreshIntervalMinutes: Int = 15 // matches SettingsView

    var body: some View {
        NavigationSplitView {
            // Sidebar
            SidebarView()
        } detail: {
            // Main content with transition animation
            Group {
                switch viewModel.selectedTab {
                case .dashboard:
                    DashboardView()
                case .assets:
                    AssetsView()
                case .transactions:
                    TransactionsView()
                case .plans:
                    PlansView()
                case .news:
                    NewsView()
                case .analysis:
                    AIAnalysisView()
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .animation(Theme.Animation.standard, value: viewModel.selectedTab)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.body)
                        .foregroundColor(.accentColor)
                    Text("AssetMonitor")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
            }

            ToolbarItemGroup(placement: .primaryAction) {
                // Last refreshed indicator
                if let lastRefreshed = viewModel.lastRefreshed {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(lastRefreshed, style: .relative)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .help("Last updated: \(lastRefreshed.formatted())")
                }

                // Refresh button with keyboard shortcut
                Button(action: refreshPrices) {
                    HStack(spacing: Theme.Spacing.xs) {
                        if viewModel.isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                        }
                        Text("Refresh")
                            .font(.subheadline)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.refresh)
                .disabled(viewModel.isRefreshing)
                .help("Refresh prices (⌘R)")
            }
        }
        // Keyboard shortcuts for navigation
        .background(
            Group {
                Button("") { viewModel.selectedTab = .dashboard }
                    .keyboardShortcut(.dashboard)
                    .hidden()
                Button("") { viewModel.selectedTab = .assets }
                    .keyboardShortcut(.assets)
                    .hidden()
                Button("") { viewModel.selectedTab = .transactions }
                    .keyboardShortcut(.transactions)
                    .hidden()
                Button("") { viewModel.selectedTab = .plans }
                    .keyboardShortcut(.plans)
                    .hidden()
                Button("") { viewModel.selectedTab = .news }
                    .keyboardShortcut(.news)
                    .hidden()
                Button("") { viewModel.selectedTab = .analysis }
                    .keyboardShortcut(.aiAnalysis)
                    .hidden()
            }
        )
        .task {
            // Sync widget data immediately on launch with current data
            viewModel.syncAllWidgetData()

            // Then refresh prices (which will sync again with updated prices)
            await viewModel.refreshPrices()
            await viewModel.refreshNews()
            setupAutoRefresh()
        }
        .onChange(of: refreshIntervalMinutes) { _, _ in
            setupAutoRefresh()
        }
        .onDisappear {
            autoRefreshTimer?.invalidate()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    private func refreshPrices() {
        Task {
            await viewModel.refreshPrices()
        }
    }

    private func setupAutoRefresh() {
        guard refreshIntervalMinutes > 0 else { return }

        autoRefreshTimer?.invalidate()
        let intervalSeconds = TimeInterval(refreshIntervalMinutes * 60)
        autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
            Task { @MainActor in
                await viewModel.refreshPrices()
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @State private var hoveredTab: AppTab?

    var body: some View {
        List(selection: $viewModel.selectedTab) {
            Section("Overview") {
                ForEach([AppTab.dashboard, AppTab.assets], id: \.self) { tab in
                    SidebarTabItem(tab: tab, shortcut: tab == .dashboard ? "⌘1" : "⌘2")
                        .tag(tab)
                }
            }

            Section("Activity") {
                ForEach([AppTab.transactions, AppTab.plans], id: \.self) { tab in
                    SidebarTabItem(tab: tab, shortcut: tab == .transactions ? "⌘3" : "⌘4")
                        .tag(tab)
                }
            }

            Section("Insights") {
                SidebarTabItem(tab: .news, shortcut: "⌘5")
                    .tag(AppTab.news)
                SidebarTabItem(tab: .analysis, shortcut: "⌘6")
                    .tag(AppTab.analysis)
            }

            Section("Quick Stats") {
                QuickStatsView()
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }
}

struct SidebarTabItem: View {
    let tab: AppTab
    let shortcut: String
    @State private var isHovered = false

    var body: some View {
        HStack {
            Label(tab.rawValue, systemImage: tab.iconName)
            Spacer()
            Text(shortcut)
                .font(.caption2)
                .foregroundColor(.secondary)
                .opacity(isHovered ? 1 : 0)
        }
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

struct QuickStatsView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            QuickStatRow(
                label: "Portfolio",
                value: viewModel.totalPortfolioValue.formatted(.currency(code: "USD")),
                color: .primary
            )

            QuickStatRow(
                label: "Today",
                value: viewModel.dailyChange.formatted(.currency(code: "USD")),
                change: viewModel.dailyChangePercent,
                color: Theme.StatusColors.changeColor(for: viewModel.dailyChange)
            )

            QuickStatRow(
                label: "Total Return",
                value: viewModel.totalGainLoss.formatted(.currency(code: "USD")),
                change: viewModel.totalGainLossPercent,
                color: Theme.StatusColors.changeColor(for: viewModel.totalGainLoss)
            )

            // Overdue plans indicator
            if !viewModel.overduePlans.isEmpty {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("\(viewModel.overduePlans.count) overdue")
                        .foregroundColor(.orange)
                    Spacer()
                }
                .font(.caption)
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

struct QuickStatRow: View {
    let label: String
    let value: String
    var change: Double? = nil
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(value)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                    .contentTransition(.numericText())
                if let change = change {
                    Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.1f")%")
                        .font(.caption2)
                        .foregroundColor(color)
                }
            }
        }
        .font(.caption)
    }
}

#Preview {
    MainView()
        .environmentObject(PortfolioViewModel())
}
