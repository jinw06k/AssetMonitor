import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.openWindow) var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("AssetMonitor")
                    .font(.headline)

                if viewModel.isPrivacyModeEnabled {
                    Text("••••••")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text(viewModel.totalPortfolioValue, format: .currency(code: "USD"))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }

                HStack(spacing: 8) {
                    // Daily change
                    HStack(spacing: 2) {
                        Image(systemName: viewModel.dailyChange >= 0 ? "arrow.up" : "arrow.down")
                        if !viewModel.isPrivacyModeEnabled {
                            Text(abs(viewModel.dailyChange), format: .currency(code: "USD"))
                        }
                    }
                    .foregroundColor(viewModel.dailyChange >= 0 ? .green : .red)

                    Text("(\(viewModel.dailyChangePercent >= 0 ? "+" : "")\(viewModel.dailyChangePercent, specifier: "%.2f")%)")
                        .foregroundColor(viewModel.dailyChange >= 0 ? .green : .red)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Holdings
            if databaseService.assets.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "building.columns")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No holdings yet")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(databaseService.assets.sorted { $0.totalValue > $1.totalValue }.prefix(7)) { asset in
                            MenuBarAssetRow(asset: asset, isPrivacyMode: viewModel.isPrivacyModeEnabled)
                        }

                        if databaseService.assets.count > 7 {
                            Text("+ \(databaseService.assets.count - 7) more")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            // Allocation summary
            HStack(spacing: 16) {
                AllocationBadge(
                    label: "Stocks",
                    percentage: viewModel.totalPortfolioValue > 0
                        ? (viewModel.stocksValue / viewModel.totalPortfolioValue) * 100
                        : 0,
                    color: .blue
                )

                AllocationBadge(
                    label: "ETFs",
                    percentage: viewModel.totalPortfolioValue > 0
                        ? (viewModel.etfsValue / viewModel.totalPortfolioValue) * 100
                        : 0,
                    color: .green
                )

                AllocationBadge(
                    label: "CDs",
                    percentage: viewModel.totalPortfolioValue > 0
                        ? (viewModel.cdsValue / viewModel.totalPortfolioValue) * 100
                        : 0,
                    color: .orange
                )
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Button(action: {
                    Task {
                        await viewModel.refreshPrices()
                    }
                }) {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isRefreshing)

                Button(action: {
                    viewModel.isPrivacyModeEnabled.toggle()
                }) {
                    Image(systemName: viewModel.isPrivacyModeEnabled ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.bordered)
                .help(viewModel.isPrivacyModeEnabled ? "Disable Privacy Mode" : "Enable Privacy Mode")

                Spacer()

                Button("Open App") {
                    NSApp.activate(ignoringOtherApps: true)
                    if let window = NSApp.windows.first(where: { $0.title == "AssetMonitor" || $0.identifier?.rawValue.contains("main") == true }) {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            // Last updated
            if let lastRefreshed = viewModel.lastRefreshed {
                Text("Updated \(lastRefreshed, style: .relative) ago")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 8)
            }
        }
        .frame(width: 320)
    }
}

// MARK: - Menu Bar Asset Row

struct MenuBarAssetRow: View {
    let asset: Asset
    let isPrivacyMode: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(asset.symbol)
                    .fontWeight(.medium)
                if !isPrivacyMode {
                    Text("\(asset.totalShares, specifier: "%.2f") shares")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                if !isPrivacyMode, let price = asset.currentPrice {
                    Text(price, format: .currency(code: "USD"))
                        .fontWeight(.medium)
                }

                HStack(spacing: 2) {
                    Image(systemName: asset.dailyChangePercent >= 0 ? "arrow.up" : "arrow.down")
                    Text("\(abs(asset.dailyChangePercent), specifier: "%.2f")%")
                }
                .font(.caption)
                .foregroundColor(asset.dailyChangePercent >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.clear)
    }
}

// MARK: - Allocation Badge

struct AllocationBadge: View {
    let label: String
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(percentage, specifier: "%.0f")%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
