import SwiftUI

struct NewsView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var selectedSymbol: String? = nil
    @State private var isRefreshing = false

    var filteredNews: [StockNews] {
        var news = viewModel.stockNews

        if let symbol = selectedSymbol {
            news = news.filter { $0.symbol == symbol }
        }

        return news.sorted { $0.publishedDate > $1.publishedDate }
    }

    var availableSymbols: [String] {
        let symbols = databaseService.assets
            .filter { $0.type != .cd && $0.type != .cash }
            .map { $0.symbol }
        return Array(Set(symbols)).sorted()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with symbol filter buttons
            VStack(spacing: Theme.Spacing.md) {
                HStack {
                    Text("Stock News")
                        .font(.title2)
                        .fontWeight(.bold)

                    Spacer()

                    // News count
                    Text("\(filteredNews.count) articles this week")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Refresh button
                    Button(action: refreshNews) {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRefreshing)
                }

                // Horizontal symbol filter buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.sm) {
                        // All button
                        SymbolFilterButton(
                            symbol: "All",
                            isSelected: selectedSymbol == nil,
                            color: .blue
                        ) {
                            withAnimation(Theme.Animation.quick) {
                                selectedSymbol = nil
                            }
                        }

                        // Individual symbol buttons
                        ForEach(availableSymbols, id: \.self) { symbol in
                            let asset = databaseService.assets.first { $0.symbol == symbol }
                            let color = asset.map { Theme.AssetColors.color(for: $0.type) } ?? .blue

                            SymbolFilterButton(
                                symbol: symbol,
                                isSelected: selectedSymbol == symbol,
                                color: color
                            ) {
                                withAnimation(Theme.Animation.quick) {
                                    selectedSymbol = symbol
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.xs)
                }
            }
            .padding()
            .background(Theme.Colors.cardBackground)

            Divider()

            // News List
            if databaseService.assets.filter({ $0.type != .cd && $0.type != .cash }).isEmpty {
                EmptyStateView(
                    icon: "newspaper",
                    title: "No Holdings",
                    description: "Add stocks or ETFs to see related news",
                    action: { viewModel.selectedTab = .assets },
                    actionLabel: "Add Assets"
                )
            } else if filteredNews.isEmpty {
                if isRefreshing || viewModel.isLoadingNews {
                    VStack(spacing: Theme.Spacing.lg) {
                        ProgressView()
                        Text("Loading news...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    EmptyStateView(
                        icon: "newspaper",
                        title: "No Recent News",
                        description: "No news from the past week for \(selectedSymbol ?? "your holdings")",
                        action: refreshNews,
                        actionLabel: "Refresh"
                    )
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.md) {
                        ForEach(filteredNews) { news in
                            NewsCardWithImage(news: news)
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            if viewModel.stockNews.isEmpty {
                await viewModel.refreshNews()
            }
        }
    }

    private func refreshNews() {
        isRefreshing = true
        Task {
            await viewModel.refreshNews()
            isRefreshing = false
        }
    }
}

// MARK: - Symbol Filter Button

struct SymbolFilterButton: View {
    let symbol: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .fill(isSelected ? color : color.opacity(isHovered ? 0.15 : 0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                        .stroke(isSelected ? Color.clear : color.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(Theme.Animation.quick, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - News Card with Image

struct NewsCardWithImage: View {
    let news: StockNews
    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?

    var body: some View {
        Button(action: openLink) {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                // Thumbnail image
                Group {
                    if let image = thumbnailImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 80)
                            .clipped()
                            .cornerRadius(Theme.CornerRadius.medium)
                    } else if news.thumbnailURL != nil {
                        // Loading placeholder
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 120, height: 80)
                            .overlay(
                                ProgressView()
                                    .scaleEffect(0.6)
                            )
                    } else {
                        // No image placeholder
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 120, height: 80)
                            .overlay(
                                Image(systemName: "newspaper.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue.opacity(0.5))
                            )
                    }
                }

                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    // Symbol badge
                    Text(news.symbol)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(Theme.CornerRadius.small)

                    Text(news.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    HStack {
                        Text(news.publisher)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(news.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .opacity(isHovered ? 1 : 0.5)
                    }
                }
            }
            .padding()
            .frame(height: 110)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .shadow(color: isHovered ? Color.black.opacity(0.1) : Color.clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(Theme.Animation.quick, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .task {
            await loadThumbnail()
        }
    }

    private func openLink() {
        if let url = URL(string: news.link) {
            NSWorkspace.shared.open(url)
        }
    }

    private func loadThumbnail() async {
        guard let urlString = news.thumbnailURL,
              let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                await MainActor.run {
                    self.thumbnailImage = image
                }
            }
        } catch {
            // Silently fail - just show placeholder
        }
    }
}

// MARK: - News Card (Legacy - kept for compatibility)

struct NewsCard: View {
    let news: StockNews
    @State private var isHovered = false

    var body: some View {
        Button(action: openLink) {
            HStack(alignment: .top, spacing: Theme.Spacing.lg) {
                // Symbol badge
                VStack {
                    Text(news.symbol)
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xs)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(Theme.CornerRadius.small)
                }
                .frame(width: 60)

                // Content
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(news.title)
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack {
                        Text(news.publisher)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .foregroundColor(.secondary)

                        Text(news.timeAgo)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .opacity(isHovered ? 1 : 0.5)
                    }
                }
            }
            .padding()
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.01 : 1.0)
            .animation(Theme.Animation.quick, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func openLink() {
        if let url = URL(string: news.link) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - News Summary Card (for Dashboard)

struct NewsSummaryCard: View {
    let news: [StockNews]
    let onViewAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader(
                title: "Latest News",
                subtitle: "\(news.count) articles",
                action: onViewAll,
                actionLabel: "View All"
            )

            if news.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: "newspaper")
                            .font(.title)
                            .foregroundColor(.secondary)
                        Text("No recent news")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xl)
                    Spacer()
                }
            } else {
                ForEach(news.prefix(3)) { item in
                    NewsRowCompact(news: item)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Compact News Row

struct NewsRowCompact: View {
    let news: StockNews
    @State private var isHovered = false

    var body: some View {
        Button(action: openLink) {
            HStack(spacing: Theme.Spacing.md) {
                Text(news.symbol)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                    .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(news.title)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text("\(news.publisher) • \(news.timeAgo)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(.vertical, Theme.Spacing.xs)
            .background(isHovered ? Theme.Colors.overlay(opacity: 0.05) : Color.clear)
            .cornerRadius(Theme.CornerRadius.small)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Theme.Animation.quick) {
                isHovered = hovering
            }
        }
    }

    private func openLink() {
        if let url = URL(string: news.link) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    NewsView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
