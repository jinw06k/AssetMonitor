import SwiftUI
import WidgetKit

struct SettingsView: View {
    @EnvironmentObject var databaseService: DatabaseService
    @EnvironmentObject var viewModel: PortfolioViewModel

    @AppStorage("openai_api_key") private var openAIKey = ""
    @AppStorage("refresh_interval") private var refreshInterval = 15
    @AppStorage("show_cents") private var showCents = true
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true

    @State private var showingAPIKey = false
    @State private var showingExportAlert = false
    @State private var showingImportAlert = false
    @State private var showingResetAlert = false
    @State private var widgetDebugInfo: String?

    var body: some View {
        TabView {
            // General Settings
            Form {
                Section("Display") {
                    Toggle("Show cents in values", isOn: $showCents)

                    Picker("Auto-refresh interval", selection: $refreshInterval) {
                        Text("5 minutes").tag(5)
                        Text("15 minutes").tag(15)
                        Text("30 minutes").tag(30)
                        Text("1 hour").tag(60)
                        Text("Manual only").tag(0)
                    }

                    if refreshInterval > 0 {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.secondary)
                            Text("Prices will auto-refresh every \(refreshInterval) minutes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Privacy") {
                    Toggle("Privacy Mode", isOn: $viewModel.isPrivacyModeEnabled)

                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.secondary)
                        Text("When enabled, widgets and menu bar show percentages only instead of dollar amounts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Keyboard Shortcuts") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        ShortcutRow(keys: "⌘R", description: "Refresh prices")
                        ShortcutRow(keys: "⌘N", description: "Add new asset")
                        ShortcutRow(keys: "⌘1-6", description: "Switch between tabs")
                    }
                }

                Section("Notifications") {
                    Toggle("Enable notifications", isOn: $notificationsEnabled)

                    if notificationsEnabled {
                        Text("You'll receive notifications for:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Label("Overdue DCA purchases", systemImage: "calendar.badge.exclamationmark")
                            Label("Significant price changes (>5%)", systemImage: "chart.line.uptrend.xyaxis")
                            Label("CD maturity dates", systemImage: "banknote")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("General", systemImage: "gear")
            }

            // API Settings
            Form {
                Section("OpenAI API") {
                    HStack {
                        if showingAPIKey {
                            TextField("API Key", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("API Key", text: $openAIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { showingAPIKey.toggle() }) {
                            Image(systemName: showingAPIKey ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }

                    if openAIKey.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.StatusColors.warning)
                            Text("API key required for AI analysis features")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("API key configured")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                        .font(.caption)
                }

                Section("API Usage") {
                    Text("AI analysis uses the GPT-4 model. Each analysis costs approximately $0.03-0.06 depending on portfolio size.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("API", systemImage: "key")
            }

            // Data Settings
            Form {
                Section("Data Management") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Assets")
                            Text("\(databaseService.assets.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Transactions")
                            Text("\(databaseService.transactions.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .leading) {
                            Text("Plans")
                            Text("\(databaseService.investmentPlans.count) items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Export & Import") {
                    Button("Export Data to CSV") {
                        exportData()
                    }

                    Button("Export Data to JSON") {
                        exportJSON()
                    }

                    Text("Exports will be saved to your Downloads folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Section("Database") {
                    HStack {
                        Text("Location")
                        Spacer()
                        Text("~/Library/Application Support/AssetMonitor/")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Button("Reveal in Finder") {
                        revealDatabase()
                    }
                }

                Section("Widget") {
                    Button("Force Sync to Widget") {
                        forceWidgetSync()
                    }

                    if let debugInfo = widgetDebugInfo {
                        Text(debugInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Danger Zone") {
                    Button("Reset All Data", role: .destructive) {
                        showingResetAlert = true
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("Data", systemImage: "externaldrive")
            }

            // About
            Form {
                Section {
                    VStack(spacing: Theme.Spacing.lg) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.accentColor, .accentColor.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 36))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: Theme.Spacing.xs) {
                            Text("AssetMonitor")
                                .font(.title)
                                .fontWeight(.bold)

                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Text("A personal portfolio tracker for stocks, ETFs, CDs, and cash with AI-powered analysis and intelligent DCA planning.")
                            .multilineTextAlignment(.center)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }

                Section("Features") {
                    FeatureRow(icon: "chart.pie.fill", title: "Portfolio Tracking", description: "Monitor stocks, ETFs, CDs, and cash")
                    FeatureRow(icon: "calendar.badge.clock", title: "DCA Planning", description: "Smart dollar-cost averaging")
                    FeatureRow(icon: "brain", title: "AI Analysis", description: "GPT-4 powered insights")
                    FeatureRow(icon: "square.grid.2x2", title: "Widgets", description: "Desktop widgets for quick access")
                }

                Section("Credits") {
                    HStack {
                        Image(systemName: "swift")
                            .foregroundColor(.accentColor)
                        Text("Built with SwiftUI")
                    }
                    HStack {
                        Image(systemName: "chart.xyaxis.line")
                            .foregroundColor(.accentColor)
                        Text("Stock data from Yahoo Finance")
                    }
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.accentColor)
                        Text("AI analysis powered by OpenAI GPT-4")
                    }
                }
            }
            .formStyle(.grouped)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 400)
        .alert("Reset All Data?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                resetData()
            }
        } message: {
            Text("This will permanently delete all your assets, transactions, and investment plans. This action cannot be undone.")
        }
    }

    private func exportData() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Export assets
        var assetsCSV = "Symbol,Type,Name,Shares,Average Cost,Current Price,Total Value,Gain/Loss %\n"
        for asset in databaseService.assets {
            assetsCSV += "\(asset.symbol),\(asset.type.rawValue),\"\(asset.name)\",\(asset.totalShares),\(asset.averageCost),\(asset.currentPrice ?? 0),\(asset.totalValue),\(asset.gainLossPercent)\n"
        }

        // Export transactions
        var transactionsCSV = "Date,Symbol,Type,Shares,Price,Total,Notes\n"
        for tx in databaseService.transactions {
            let symbol = databaseService.getAsset(byId: tx.assetId)?.symbol ?? "Unknown"
            transactionsCSV += "\(dateFormatter.string(from: tx.date)),\(symbol),\(tx.type.rawValue),\(tx.shares),\(tx.pricePerShare),\(tx.totalAmount),\"\(tx.notes ?? "")\"\n"
        }

        // Save to Downloads
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let timestamp = dateFormatter.string(from: Date())

        try? assetsCSV.write(to: downloadsURL.appendingPathComponent("assets_\(timestamp).csv"), atomically: true, encoding: .utf8)
        try? transactionsCSV.write(to: downloadsURL.appendingPathComponent("transactions_\(timestamp).csv"), atomically: true, encoding: .utf8)

        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadsURL.path)
    }

    private func exportJSON() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        struct ExportData: Codable {
            let assets: [Asset]
            let transactions: [Transaction]
            let plans: [InvestmentPlan]
            let exportDate: Date
        }

        let data = ExportData(
            assets: databaseService.assets,
            transactions: databaseService.transactions,
            plans: databaseService.investmentPlans,
            exportDate: Date()
        )

        if let jsonData = try? encoder.encode(data) {
            let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let timestamp = dateFormatter.string(from: Date())

            try? jsonData.write(to: downloadsURL.appendingPathComponent("portfolio_backup_\(timestamp).json"))
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadsURL.path)
        }
    }

    private func revealDatabase() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = appSupportURL.appendingPathComponent("AssetMonitor")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dbPath.path)
    }

    private func resetData() {
        // Delete all investment plans first
        for plan in databaseService.investmentPlans {
            databaseService.deleteInvestmentPlan(plan)
        }

        // Delete all assets (which cascades to transactions)
        for asset in databaseService.assets {
            databaseService.deleteAsset(asset)
        }

        // Reset onboarding to show welcome screen again
        hasCompletedOnboarding = false
    }

    private func forceWidgetSync() {
        let assets = databaseService.assets
        let totalValue = assets.reduce(0) { $0 + $1.totalValue }
        let assetCount = assets.count
        let planCount = databaseService.investmentPlans.filter { $0.status == .active }.count

        // Sync portfolio data
        SharedDataManager.shared.syncFromMainApp(assets: assets)

        // Sync DCA plans
        SharedDataManager.shared.syncDCAPlans(
            plans: databaseService.investmentPlans,
            assets: assets
        )

        // Force reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        // Show debug info
        let data = SharedDataManager.shared.readWidgetData()
        let dcaPlans = SharedDataManager.shared.readDCAPlansData()
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .medium
        let lastUpdateStr = data.lastUpdated.map { dateFormatter.string(from: $0) } ?? "Never"

        widgetDebugInfo = """
            Synced: \(assetCount) assets, \(planCount) plans
            Portfolio: $\(String(format: "%.2f", totalValue))
            Read back: $\(String(format: "%.2f", data.totalValue)), \(data.holdings.count) holdings
            DCA Plans: \(dcaPlans.count) synced
            Last Updated: \(lastUpdateStr)
            App Group: \(data.totalValue > 0 ? "✓ Working" : "✗ NOT WORKING")

            If widget still shows placeholder, try:
            1. Remove widget from desktop
            2. Re-add the widget
            3. Click Force Sync again
            """
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, Theme.Spacing.sm)
                .padding(.vertical, Theme.Spacing.xs)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.small)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
