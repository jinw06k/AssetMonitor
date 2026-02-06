import Foundation

/// Service for AI-powered portfolio analysis using OpenAI GPT-4
@MainActor
class OpenAIService {
    static let shared = OpenAIService()

    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let session: URLSession

    var apiKey: String {
        get { UserDefaults.standard.string(forKey: "openai_api_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openai_api_key") }
    }

    var isConfigured: Bool {
        return !apiKey.isEmpty
    }

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: config)
    }

    // MARK: - Portfolio Analysis

    func analyzePortfolio(
        assets: [Asset],
        transactions: [Transaction],
        plans: [InvestmentPlan]
    ) async throws -> PortfolioAnalysis {
        guard isConfigured else {
            throw OpenAIError.notConfigured
        }

        let prompt = buildPortfolioPrompt(assets: assets, transactions: transactions, plans: plans)
        let response = try await sendRequest(prompt: prompt)

        return PortfolioAnalysis(
            summary: response,
            timestamp: Date(),
            portfolioSnapshot: buildSnapshot(assets: assets)
        )
    }

    // MARK: - Asset-Specific Analysis

    func analyzeAsset(asset: Asset, transactions: [Transaction]) async throws -> String {
        guard isConfigured else {
            throw OpenAIError.notConfigured
        }

        let prompt = buildAssetPrompt(asset: asset, transactions: transactions)
        return try await sendRequest(prompt: prompt)
    }

    // MARK: - Investment Plan Suggestions

    func suggestInvestmentPlan(
        asset: Asset,
        amount: Double,
        currentMarketConditions: String? = nil
    ) async throws -> String {
        guard isConfigured else {
            throw OpenAIError.notConfigured
        }

        let prompt = """
        I'm planning to invest $\(String(format: "%.2f", amount)) in \(asset.name) (\(asset.symbol)).

        Current price: $\(String(format: "%.2f", asset.currentPrice ?? 0))
        Asset type: \(asset.type.displayName)

        Please suggest an optimal dollar-cost averaging (DCA) strategy including:
        1. Recommended number of purchases
        2. Suggested frequency (weekly, bi-weekly, monthly)
        3. Amount per purchase
        4. Any market timing considerations
        5. Risk factors to consider

        Keep the response concise and actionable.
        """

        return try await sendRequest(prompt: prompt, systemPrompt: investmentAdvisorPrompt)
    }

    // MARK: - Private Methods

    private func sendRequest(prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt ?? financialAnalystPrompt],
            ["role": "user", "content": prompt]
        ]

        let body: [String: Any] = [
            "model": "gpt-4",
            "messages": messages,
            "max_tokens": 1500,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed
        }

        if httpResponse.statusCode == 401 {
            throw OpenAIError.invalidAPIKey
        }

        if httpResponse.statusCode == 429 {
            throw OpenAIError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw OpenAIError.requestFailed
        }

        return try parseResponse(data: data)
    }

    private func parseResponse(data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.parseError
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Prompt Builders

    private func buildPortfolioPrompt(
        assets: [Asset],
        transactions: [Transaction],
        plans: [InvestmentPlan]
    ) -> String {
        var prompt = "Please analyze my investment portfolio:\n\n"

        // Portfolio summary
        let totalValue = assets.reduce(0) { $0 + $1.totalValue }
        let totalCost = assets.reduce(0) { $0 + $1.totalCost }
        let totalGain = totalValue - totalCost
        let gainPercent = totalCost > 0 ? (totalGain / totalCost) * 100 : 0

        prompt += "## Portfolio Summary\n"
        prompt += "- Total Value: $\(String(format: "%.2f", totalValue))\n"
        prompt += "- Total Invested: $\(String(format: "%.2f", totalCost))\n"
        prompt += "- Total Gain/Loss: $\(String(format: "%.2f", totalGain)) (\(String(format: "%.1f", gainPercent))%)\n\n"

        // Asset breakdown
        prompt += "## Holdings\n"
        for asset in assets.sorted(by: { $0.totalValue > $1.totalValue }) {
            let allocation = totalValue > 0 ? (asset.totalValue / totalValue) * 100 : 0
            prompt += "- \(asset.symbol) (\(asset.type.displayName)): "
            prompt += "$\(String(format: "%.2f", asset.totalValue)) "
            prompt += "(\(String(format: "%.1f", allocation))% of portfolio), "
            prompt += "Gain: \(String(format: "%.1f", asset.gainLossPercent))%\n"
        }

        // Active DCA plans
        let activePlans = plans.filter { $0.status == .active }
        if !activePlans.isEmpty {
            prompt += "\n## Active Investment Plans\n"
            for plan in activePlans {
                if let asset = assets.first(where: { $0.id == plan.assetId }) {
                    prompt += "- \(asset.symbol): $\(String(format: "%.2f", plan.totalAmount)) over \(plan.numberOfPurchases) purchases "
                    prompt += "(\(plan.completedPurchases)/\(plan.numberOfPurchases) complete)\n"
                }
            }
        }

        prompt += """

        Please provide:
        1. Overall portfolio health assessment
        2. Diversification analysis (by asset type, sector, risk level)
        3. Top 3 strengths and weaknesses
        4. Specific actionable recommendations
        5. Risk assessment (1-10 scale with explanation)

        Keep the analysis concise but insightful.
        """

        return prompt
    }

    private func buildAssetPrompt(asset: Asset, transactions: [Transaction]) -> String {
        var prompt = "Please analyze my position in \(asset.name) (\(asset.symbol)):\n\n"

        prompt += "- Type: \(asset.type.displayName)\n"
        prompt += "- Shares: \(String(format: "%.4f", asset.totalShares))\n"
        prompt += "- Average Cost: $\(String(format: "%.2f", asset.averageCost))\n"
        prompt += "- Current Price: $\(String(format: "%.2f", asset.currentPrice ?? 0))\n"
        prompt += "- Total Value: $\(String(format: "%.2f", asset.totalValue))\n"
        prompt += "- Gain/Loss: \(String(format: "%.1f", asset.gainLossPercent))%\n"

        let recentTx = transactions.prefix(5)
        if !recentTx.isEmpty {
            prompt += "\nRecent Transactions:\n"
            let formatter = DateFormatter()
            formatter.dateStyle = .short

            for tx in recentTx {
                prompt += "- \(formatter.string(from: tx.date)): \(tx.type.displayName) "
                prompt += "\(String(format: "%.2f", tx.shares)) @ $\(String(format: "%.2f", tx.pricePerShare))\n"
            }
        }

        prompt += """

        Please provide:
        1. Position assessment
        2. Whether to hold, add more, or reduce position
        3. Key factors to watch
        4. Risk level for this holding
        """

        return prompt
    }

    private func buildSnapshot(assets: [Asset]) -> PortfolioSnapshot {
        let stocks = assets.filter { $0.type == .stock }
        let etfs = assets.filter { $0.type == .etf }
        let cds = assets.filter { $0.type == .cd }
        let treasuries = assets.filter { $0.type == .treasury }
        let cash = assets.filter { $0.type == .cash }

        return PortfolioSnapshot(
            totalValue: assets.reduce(0) { $0 + $1.totalValue },
            stocksValue: stocks.reduce(0) { $0 + $1.totalValue },
            etfsValue: etfs.reduce(0) { $0 + $1.totalValue },
            cdsValue: cds.reduce(0) { $0 + $1.totalValue },
            treasuryValue: treasuries.reduce(0) { $0 + $1.totalValue },
            cashValue: cash.reduce(0) { $0 + $1.totalValue },
            numberOfHoldings: assets.count
        )
    }

    // MARK: - System Prompts

    private let financialAnalystPrompt = """
    You are a knowledgeable financial analyst assistant. Provide clear, actionable investment analysis.

    Guidelines:
    - Be concise but thorough
    - Use bullet points for clarity
    - Provide specific, actionable recommendations
    - Always mention relevant risks
    - Use plain language, avoid jargon
    - Do not provide specific price targets or guarantees
    - Remind the user that past performance doesn't guarantee future results
    - This is for informational purposes only, not financial advice
    """

    private let investmentAdvisorPrompt = """
    You are an investment planning assistant specializing in dollar-cost averaging strategies.

    Guidelines:
    - Focus on practical DCA implementation
    - Consider market volatility in your recommendations
    - Provide specific numbers and timelines
    - Explain the reasoning behind your suggestions
    - This is for informational purposes only, not financial advice
    """
}

// MARK: - Data Models

struct PortfolioAnalysis: Identifiable, Hashable, Equatable {
    let id = UUID()
    let summary: String
    let timestamp: Date
    let portfolioSnapshot: PortfolioSnapshot
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PortfolioAnalysis, rhs: PortfolioAnalysis) -> Bool {
        lhs.id == rhs.id
    }
}

struct PortfolioSnapshot: Hashable, Equatable {
    let totalValue: Double
    let stocksValue: Double
    let etfsValue: Double
    let cdsValue: Double
    let treasuryValue: Double
    let cashValue: Double
    let numberOfHoldings: Int
}

// MARK: - Errors

enum OpenAIError: Error, LocalizedError {
    case notConfigured
    case invalidURL
    case invalidAPIKey
    case requestFailed
    case parseError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "OpenAI API key not configured. Please add your API key in Settings."
        case .invalidURL: return "Invalid API URL"
        case .invalidAPIKey: return "Invalid API key. Please check your OpenAI API key in Settings."
        case .requestFailed: return "Request failed. Please try again."
        case .parseError: return "Failed to parse AI response"
        case .rateLimited: return "Rate limited. Please wait a moment and try again."
        }
    }
}
