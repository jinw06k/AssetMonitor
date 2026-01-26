import SwiftUI

struct AssetsView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var showingAddSheet = false
    @State private var searchText = ""
    @State private var filterType: AssetType?
    @State private var sortOption: SortOption = .value

    enum SortOption: String, CaseIterable {
        case name = "Name"
        case value = "Value"
        case gainLoss = "Gain/Loss"
        case dailyChange = "Daily Change"
    }

    var filteredAssets: [Asset] {
        var assets = databaseService.assets

        // Filter by search
        if !searchText.isEmpty {
            assets = assets.filter {
                $0.symbol.localizedCaseInsensitiveContains(searchText) ||
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Filter by type
        if let type = filterType {
            assets = assets.filter { $0.type == type }
        }

        // Sort
        switch sortOption {
        case .name:
            assets.sort { $0.symbol < $1.symbol }
        case .value:
            assets.sort { $0.totalValue > $1.totalValue }
        case .gainLoss:
            assets.sort { $0.gainLossPercent > $1.gainLossPercent }
        case .dailyChange:
            assets.sort { $0.dailyChangePercent > $1.dailyChangePercent }
        }

        return assets
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search assets...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.Spacing.sm)
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.medium)
                .frame(maxWidth: 250)

                // Filter by type
                Picker("Type", selection: $filterType) {
                    Text("All Types").tag(nil as AssetType?)
                    ForEach(AssetType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type as AssetType?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                // Sort
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 130)

                Spacer()

                // Asset count
                if !filteredAssets.isEmpty {
                    Text("\(filteredAssets.count) asset\(filteredAssets.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                }

                Button(action: { showingAddSheet = true }) {
                    Label("Add Asset", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.addNew)
            }
            .padding()

            Divider()

            // Asset List
            if filteredAssets.isEmpty {
                EmptyStateView(
                    icon: "building.columns",
                    title: "No Assets",
                    description: searchText.isEmpty ? "Add your first asset to get started" : "No assets match your search",
                    action: searchText.isEmpty ? { showingAddSheet = true } : nil,
                    actionLabel: searchText.isEmpty ? "Add Asset" : nil
                )
            } else {
                List {
                    ForEach(Array(filteredAssets.enumerated()), id: \.element.id) { index, asset in
                        AssetRowView(asset: asset)
                            .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                            .contextMenu {
                                Button {
                                    viewModel.selectedAsset = asset
                                    viewModel.selectedTab = .transactions
                                } label: {
                                    Label("Add Transaction", systemImage: "plus.circle")
                                }
                                Button {
                                    viewModel.selectedAsset = asset
                                    viewModel.selectedTab = .plans
                                } label: {
                                    Label("View Plans", systemImage: "calendar.badge.clock")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    withAnimation {
                                        viewModel.deleteAsset(asset)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
                .animation(Theme.Animation.standard, value: filteredAssets.count)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddAssetSheet()
        }
    }
}

// MARK: - Asset Row View

struct AssetRowView: View {
    let asset: Asset
    @State private var isHovered = false

    private var typeColor: Color {
        Theme.AssetColors.color(for: asset.type)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(typeColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: asset.type.iconName)
                    .font(.system(size: Theme.IconSize.medium))
                    .foregroundColor(typeColor)
            }

            // Symbol and Name
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(spacing: Theme.Spacing.sm) {
                    Text(asset.symbol)
                        .font(.headline)
                    StatusBadge(text: asset.type.displayName, color: typeColor)
                }
                Text(asset.name)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Shares and Average Cost (for tradable assets)
            if asset.type != .cash {
                VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                    if asset.type == .cd {
                        Text("Principal")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(format: "%.4f shares", asset.totalShares))
                            .font(.subheadline)
                    }
                    Text("Avg: \(asset.averageCost, format: .currency(code: "USD"))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 120, alignment: .trailing)
            }

            // Current Price / CD Info / Cash Balance
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                if asset.type == .cd {
                    if let rate = asset.cdInterestRate {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "percent")
                                .font(.caption)
                            Text(String(format: "%.2f%% APY", rate))
                        }
                        .font(.subheadline)
                        .foregroundColor(Theme.StatusColors.positive)
                    }
                    if let maturity = asset.cdMaturityDate {
                        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: maturity).day ?? 0
                        if daysRemaining > 0 {
                            Text("\(daysRemaining) days left")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Matured!")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(Theme.StatusColors.warning)
                        }
                    }
                } else if asset.type == .cash {
                    Text("Balance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    if let price = asset.currentPrice {
                        Text(price, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .contentTransition(.numericText())
                    } else {
                        Text("--")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    ChangeIndicator(value: asset.dailyChangePercent, format: .percent, font: .caption)
                }
            }
            .frame(width: 110, alignment: .trailing)

            // Total Value and Gain/Loss
            VStack(alignment: .trailing, spacing: Theme.Spacing.xxs) {
                Text(asset.totalValue, format: .currency(code: "USD"))
                    .font(.headline)
                    .contentTransition(.numericText())

                if asset.type != .cash {
                    HStack(spacing: Theme.Spacing.xs) {
                        ChangeIndicator(value: asset.gainLossPercent, format: .percent, showIcon: false, font: .caption)
                        Text("(\(asset.gainLoss >= 0 ? "+" : "")\(asset.gainLoss, format: .currency(code: "USD")))")
                            .font(.caption)
                            .foregroundColor(Theme.StatusColors.changeColor(for: asset.gainLoss))
                    }
                }
            }
            .frame(width: 160, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.sm)
        .background(isHovered ? Theme.Colors.overlay(opacity: 0.03) : Color.clear)
        .cornerRadius(Theme.CornerRadius.medium)
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Add Asset Sheet

struct AddAssetSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    @State private var assetType: AssetType = .stock
    @State private var symbol = ""
    @State private var name = ""
    @State private var cdMaturityDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
    @State private var cdInterestRate = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var isValid: Bool {
        if assetType == .cd {
            return !name.isEmpty && !cdInterestRate.isEmpty
        }
        if assetType == .cash {
            return !name.isEmpty
        }
        return !symbol.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Asset")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Picker("Asset Type", selection: $assetType) {
                    ForEach(AssetType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom)

                if assetType == .cash {
                    // Cash account form
                    Section("Cash Account Details") {
                        TextField("Account Name (e.g., Brokerage Cash)", text: $name)
                            .textFieldStyle(.roundedBorder)

                        TextField("Initial Balance", text: $cdInterestRate)
                            .textFieldStyle(.roundedBorder)

                        Text("You can deposit or withdraw funds after creating the account.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if assetType != .cd {
                    // Stock/ETF/Treasury form
                    Section("\(assetType.displayName) Details") {
                        TextField("Symbol (e.g., AAPL, QQQ, SGOV)", text: $symbol)
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)

                        TextField("Name (optional)", text: $name)
                            .textFieldStyle(.roundedBorder)

                        // Quick add suggestions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Popular \(assetType.displayName)\(assetType == .treasury ? "" : "s"):")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            let suggestions: [(symbol: String, name: String)] = {
                                switch assetType {
                                case .stock: return Asset.popularStocks
                                case .etf: return Asset.popularETFs
                                case .treasury: return Asset.popularTreasuries
                                default: return []
                                }
                            }()
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                                ForEach(suggestions.prefix(8), id: \.symbol) { item in
                                    Button(item.symbol) {
                                        symbol = item.symbol
                                        name = item.name
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.secondary)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // CD form
                    Section("Certificate of Deposit Details") {
                        TextField("CD Name (e.g., 12-Month CD)", text: $name)
                            .textFieldStyle(.roundedBorder)

                        TextField("Interest Rate (APY %)", text: $cdInterestRate)
                            .textFieldStyle(.roundedBorder)

                        DatePicker("Maturity Date", selection: $cdMaturityDate, displayedComponents: .date)
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

            // Actions
            HStack {
                Spacer()
                Button("Add Asset") {
                    addAsset()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || isLoading)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: assetType == .cd ? 350 : 450)
    }

    private func addAsset() {
        isLoading = true
        errorMessage = nil

        Task {
            if assetType == .cash {
                // Check if cash account already exists - use single consolidated cash
                let existingCash = DatabaseService.shared.assets.first(where: { $0.type == .cash })

                if existingCash == nil {
                    // Create cash account only if none exists
                    await viewModel.addAsset(
                        symbol: "CASH",
                        type: .cash,
                        name: "Cash"
                    )
                }

                // Add initial balance if specified
                if let initialBalance = Double(cdInterestRate), initialBalance > 0 {
                    if let cashAsset = DatabaseService.shared.assets.first(where: { $0.type == .cash }) {
                        viewModel.addTransaction(
                            asset: cashAsset,
                            type: .deposit,
                            date: Date(),
                            shares: 1,
                            pricePerShare: initialBalance,
                            notes: name.isEmpty ? "Deposit" : name,
                            linkedPlanId: nil,
                            updateCash: false
                        )
                    }
                }
            } else if assetType == .cd {
                let rate = Double(cdInterestRate) ?? 0
                await viewModel.addAsset(
                    symbol: "CD-\(UUID().uuidString.prefix(4))",
                    type: .cd,
                    name: name,
                    cdMaturityDate: cdMaturityDate,
                    cdInterestRate: rate
                )
            } else {
                await viewModel.addAsset(
                    symbol: symbol.uppercased(),
                    type: assetType,
                    name: name
                )
            }

            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    AssetsView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
