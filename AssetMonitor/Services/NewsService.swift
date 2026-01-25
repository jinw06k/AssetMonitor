import Foundation

/// Service for fetching stock news from Google News RSS (free, no rate limits)
@MainActor
class NewsService {
    static let shared = NewsService()

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch News for Multiple Symbols

    func fetchNews(for symbols: [String], limit: Int = 50) async -> [StockNews] {
        Logger.debug("Fetching news for: \(symbols.joined(separator: ", "))", category: "News")

        var allNews: [StockNews] = []

        // Fetch news for each symbol (Google News RSS requires individual queries)
        for symbol in symbols {
            let symbolNews = await fetchNewsForSymbol(symbol, limit: limit / max(symbols.count, 1))
            allNews.append(contentsOf: symbolNews)
        }

        // Sort by date and limit total
        let sortedNews = allNews
            .sorted { $0.publishedDate > $1.publishedDate }
            .prefix(limit)

        Logger.debug("Total news fetched: \(sortedNews.count)", category: "News")
        return Array(sortedNews)
    }

    private func fetchNewsForSymbol(_ symbol: String, limit: Int) async -> [StockNews] {
        // Use Google News RSS - it's free with no rate limits
        let query = "\(symbol)+stock"
        let urlString = "https://news.google.com/rss/search?q=\(query)&hl=en-US&gl=US&ceid=US:en"

        guard let url = URL(string: urlString) else {
            Logger.error("Invalid URL for \(symbol)", category: "News")
            return []
        }

        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                Logger.error("No HTTP response for \(symbol)", category: "News")
                return []
            }

            guard httpResponse.statusCode == 200 else {
                Logger.error("HTTP \(httpResponse.statusCode) for \(symbol)", category: "News")
                return []
            }

            // Parse RSS XML
            let parser = RSSParser(symbol: symbol)
            var newsItems = parser.parse(data: data)

            // Limit items
            newsItems = Array(newsItems.prefix(limit))

            // Add stock logo as thumbnail (Finnhub provides free stock logos)
            newsItems = newsItems.map { news in
                StockNews(
                    id: news.id,
                    symbol: news.symbol,
                    title: news.title,
                    publisher: news.publisher,
                    link: news.link,
                    publishedDate: news.publishedDate,
                    thumbnailURL: "https://static2.finnhub.io/file/publicdatany/finnhubimage/stock_logo/\(symbol).png",
                    summary: news.summary,
                    sentimentScore: news.sentimentScore,
                    sentimentLabel: news.sentimentLabel
                )
            }

            return newsItems

        } catch {
            Logger.error("Failed to fetch news for \(symbol): \(error.localizedDescription)", category: "News")
            return []
        }
    }

    // MARK: - Fetch News for Single Symbol

    func fetchNews(for symbol: String, limit: Int = 10) async throws -> [StockNews] {
        return await fetchNews(for: [symbol], limit: limit)
    }

    // MARK: - Timing Analysis

    /// Analyzes if it's a good time to buy based on recent price trends
    func analyzeTimingForPurchase(symbol: String) async -> TimingAnalysis {
        do {
            let historicalData = try await YahooFinanceService.shared.fetchHistoricalData(symbol: symbol, range: "1mo")

            guard historicalData.count >= 5 else {
                return TimingAnalysis(recommendation: .neutral, reason: "Insufficient data")
            }

            let recentPrices = historicalData.suffix(20)
            let currentPrice = recentPrices.last?.close ?? 0
            let avgPrice = recentPrices.reduce(0) { $0 + $1.close } / Double(recentPrices.count)

            let percentFromAvg = ((currentPrice - avgPrice) / avgPrice) * 100

            let firstHalf = Array(recentPrices.prefix(10))
            let secondHalf = Array(recentPrices.suffix(10))
            let firstHalfAvg = firstHalf.reduce(0) { $0 + $1.close } / Double(firstHalf.count)
            let secondHalfAvg = secondHalf.reduce(0) { $0 + $1.close } / Double(secondHalf.count)
            let trendDirection = secondHalfAvg > firstHalfAvg ? "upward" : "downward"

            if percentFromAvg < -5 {
                return TimingAnalysis(
                    recommendation: .good,
                    reason: "Price is \(String(format: "%.1f", abs(percentFromAvg)))% below 20-day avg",
                    percentFromAverage: percentFromAvg,
                    trend: trendDirection
                )
            } else if percentFromAvg > 5 {
                return TimingAnalysis(
                    recommendation: .wait,
                    reason: "Price is \(String(format: "%.1f", percentFromAvg))% above 20-day avg",
                    percentFromAverage: percentFromAvg,
                    trend: trendDirection
                )
            } else {
                return TimingAnalysis(
                    recommendation: .neutral,
                    reason: "Price is near 20-day average",
                    percentFromAverage: percentFromAvg,
                    trend: trendDirection
                )
            }
        } catch {
            return TimingAnalysis(recommendation: .neutral, reason: "Unable to analyze")
        }
    }
}

// MARK: - RSS Parser

private class RSSParser: NSObject, XMLParserDelegate {
    private let symbol: String
    private var newsItems: [StockNews] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentSource = ""
    private var isInItem = false

    init(symbol: String) {
        self.symbol = symbol
    }

    func parse(data: Data) -> [StockNews] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return newsItems
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName

        if elementName == "item" {
            isInItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentSource = ""
        } else if elementName == "source" {
            // Source element might have url attribute, but we want the text content
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInItem else { return }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        switch currentElement {
        case "title":
            currentTitle += trimmed
        case "link":
            currentLink += trimmed
        case "pubDate":
            currentPubDate += trimmed
        case "source":
            currentSource += trimmed
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            isInItem = false

            // Parse the pub date
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "E, d MMM yyyy HH:mm:ss z"
            let publishedDate = dateFormatter.date(from: currentPubDate) ?? Date()

            // Clean up title (Google News sometimes appends " - Source" to title)
            var cleanTitle = currentTitle
            if let dashRange = cleanTitle.range(of: " - ", options: .backwards) {
                // Extract source from title if not already set
                if currentSource.isEmpty {
                    currentSource = String(cleanTitle[dashRange.upperBound...])
                }
                cleanTitle = String(cleanTitle[..<dashRange.lowerBound])
            }

            // Only add if we have the required fields
            guard !cleanTitle.isEmpty, !currentLink.isEmpty else { return }

            let news = StockNews(
                id: UUID(),
                symbol: symbol,
                title: cleanTitle,
                publisher: currentSource.isEmpty ? "News" : currentSource,
                link: currentLink,
                publishedDate: publishedDate,
                thumbnailURL: nil,
                summary: nil,
                sentimentScore: nil,
                sentimentLabel: nil
            )

            newsItems.append(news)
        }
    }
}

// MARK: - Data Models

struct StockNews: Identifiable, Codable {
    let id: UUID
    let symbol: String
    let title: String
    let publisher: String
    let link: String
    let publishedDate: Date
    let thumbnailURL: String?
    var summary: String?
    var sentimentScore: Double?
    var sentimentLabel: String?

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: publishedDate, relativeTo: Date())
    }

    var sentimentColor: String {
        guard let label = sentimentLabel?.lowercased() else { return "secondary" }
        switch label {
        case "bullish", "somewhat-bullish":
            return "green"
        case "bearish", "somewhat-bearish":
            return "red"
        default:
            return "secondary"
        }
    }
}

struct TimingAnalysis: Codable {
    let recommendation: TimingRecommendation
    let reason: String
    var percentFromAverage: Double?
    var trend: String?
}

enum TimingRecommendation: String, Codable {
    case good = "good"
    case neutral = "neutral"
    case wait = "wait"

    var displayText: String {
        switch self {
        case .good: return "Good Time"
        case .neutral: return "Neutral"
        case .wait: return "Consider Waiting"
        }
    }

    var iconName: String {
        switch self {
        case .good: return "checkmark.circle.fill"
        case .neutral: return "minus.circle.fill"
        case .wait: return "clock.fill"
        }
    }

    var color: String {
        switch self {
        case .good: return "green"
        case .neutral: return "orange"
        case .wait: return "red"
        }
    }
}

// MARK: - Errors

enum NewsError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case parseError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed: return "Request failed"
        case .parseError: return "Failed to parse news"
        case .rateLimited: return "API rate limit reached. Please try again later."
        }
    }
}
