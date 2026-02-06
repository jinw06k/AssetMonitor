import SwiftUI

struct AIAnalysisView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var analysisHistory: [PortfolioAnalysis] = []
    @State private var selectedAnalysis: PortfolioAnalysis?

    var body: some View {
        HSplitView {
            // Left panel - Analysis list
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("AI Analysis")
                        .font(.headline)
                    Spacer()
                    Button(action: requestAnalysis) {
                        if viewModel.isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else {
                            Label("New Analysis", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isAnalyzing || !OpenAIService.shared.isConfigured)
                }
                .padding()

                Divider()

                if !OpenAIService.shared.isConfigured {
                    // API key not configured
                    ContentUnavailableView(
                        "API Key Required",
                        systemImage: "key.fill",
                        description: Text("Configure your OpenAI API key in Settings to enable AI analysis")
                    )
                } else if analysisHistory.isEmpty && viewModel.aiAnalysis == nil {
                    // No analyses yet
                    ContentUnavailableView(
                        "No Analyses Yet",
                        systemImage: "brain",
                        description: Text("Click 'New Analysis' to get AI-powered insights about your portfolio")
                    )
                } else {
                    // Analysis list
                    List(selection: $selectedAnalysis) {
                        if let current = viewModel.aiAnalysis {
                            AnalysisListItem(analysis: current, isCurrent: true)
                                .tag(current)
                        }

                        if !analysisHistory.isEmpty {
                            Section("Previous Analyses") {
                                ForEach(analysisHistory) { analysis in
                                    AnalysisListItem(analysis: analysis, isCurrent: false)
                                        .tag(analysis)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .frame(minWidth: 250, maxWidth: 350)

            // Right panel - Analysis detail
            if let analysis = selectedAnalysis ?? viewModel.aiAnalysis {
                AnalysisDetailView(analysis: analysis)
            } else {
                ContentUnavailableView(
                    "Select an Analysis",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Choose an analysis from the list or generate a new one")
                )
            }
        }
        .onChange(of: viewModel.aiAnalysis) { _, newAnalysis in
            if let analysis = newAnalysis {
                selectedAnalysis = analysis
                // Add to history (keep last 10)
                if !analysisHistory.contains(where: { $0.id == analysis.id }) {
                    analysisHistory.insert(analysis, at: 0)
                    if analysisHistory.count > 10 {
                        analysisHistory.removeLast()
                    }
                }
            }
        }
    }

    private func requestAnalysis() {
        Task {
            await viewModel.requestAIAnalysis()
        }
    }
}

// MARK: - Analysis List Item

struct AnalysisListItem: View {
    let analysis: PortfolioAnalysis
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                if isCurrent {
                    Text("Latest")
                        .font(.caption)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(Theme.CornerRadius.small)
                }

                Text(analysis.timestamp, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Text(analysis.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("$\(analysis.portfolioSnapshot.totalValue, specifier: "%.2f")")
                    .font(.caption)
                Text("\(analysis.portfolioSnapshot.numberOfHoldings) holdings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
    }
}

// MARK: - Analysis Detail View

struct AnalysisDetailView: View {
    let analysis: PortfolioAnalysis

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("Portfolio Analysis")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("\(analysis.timestamp, style: .date) at \(analysis.timestamp, style: .time)")
                    }
                    .foregroundColor(.secondary)

                    Spacer()

                    // Snapshot
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(analysis.portfolioSnapshot.totalValue, format: .currency(code: "USD"))
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("\(analysis.portfolioSnapshot.numberOfHoldings) holdings")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)

                // Allocation at time of analysis
                let total = analysis.portfolioSnapshot.totalValue
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: Theme.Spacing.md) {
                    SnapshotCard(
                        title: "Stocks",
                        value: analysis.portfolioSnapshot.stocksValue,
                        percentage: total > 0
                            ? (analysis.portfolioSnapshot.stocksValue / total) * 100
                            : 0,
                        color: Theme.AssetColors.stock
                    )

                    SnapshotCard(
                        title: "ETFs",
                        value: analysis.portfolioSnapshot.etfsValue,
                        percentage: total > 0
                            ? (analysis.portfolioSnapshot.etfsValue / total) * 100
                            : 0,
                        color: Theme.AssetColors.etf
                    )

                    SnapshotCard(
                        title: "Treasury",
                        value: analysis.portfolioSnapshot.treasuryValue,
                        percentage: total > 0
                            ? (analysis.portfolioSnapshot.treasuryValue / total) * 100
                            : 0,
                        color: Theme.AssetColors.treasury
                    )

                    SnapshotCard(
                        title: "CDs",
                        value: analysis.portfolioSnapshot.cdsValue,
                        percentage: total > 0
                            ? (analysis.portfolioSnapshot.cdsValue / total) * 100
                            : 0,
                        color: Theme.AssetColors.cd
                    )

                    SnapshotCard(
                        title: "Cash",
                        value: analysis.portfolioSnapshot.cashValue,
                        percentage: total > 0
                            ? (analysis.portfolioSnapshot.cashValue / total) * 100
                            : 0,
                        color: Theme.AssetColors.cash
                    )
                }

                Divider()

                // AI Analysis Content
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("AI Analysis")
                            .font(.headline)
                    }

                    // Parse and display the analysis with formatting
                    AnalysisContentView(content: analysis.summary)
                }
                .padding()
                .background(Theme.Colors.cardBackground)
                .cornerRadius(Theme.CornerRadius.large)

                // Disclaimer
                Text("This analysis is generated by AI and is for informational purposes only. It should not be considered financial advice. Always consult with a qualified financial advisor before making investment decisions.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Theme.StatusColors.warning.opacity(0.1))
                    .cornerRadius(Theme.CornerRadius.medium)
            }
            .padding()
        }
    }
}

// MARK: - Snapshot Card

struct SnapshotCard: View {
    let title: String
    let value: Double
    let percentage: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value, format: .currency(code: "USD"))
                .font(.subheadline)
                .fontWeight(.medium)
            Text("\(percentage, specifier: "%.1f")%")
                .font(.caption)
                .foregroundColor(color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .cornerRadius(Theme.CornerRadius.medium)
    }
}

// MARK: - Analysis Content View

struct AnalysisContentView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Split content by sections (looking for headers)
            ForEach(parseContent(), id: \.self) { section in
                if section.starts(with: "#") || section.starts(with: "**") {
                    // Header
                    Text(cleanHeader(section))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                } else if section.starts(with: "-") || section.starts(with: "•") {
                    // Bullet point
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.accentColor)
                        Text(section.trimmingCharacters(in: CharacterSet(charactersIn: "-• ")))
                    }
                    .font(.body)
                } else if section.first?.isNumber == true && section.contains(".") {
                    // Numbered list
                    Text(section)
                        .font(.body)
                } else if !section.isEmpty {
                    // Regular paragraph
                    Text(section)
                        .font(.body)
                }
            }
        }
    }

    private func parseContent() -> [String] {
        // Split by newlines and filter empty lines
        content.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func cleanHeader(_ text: String) -> String {
        text
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

#Preview {
    AIAnalysisView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
