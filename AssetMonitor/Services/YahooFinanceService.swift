import Foundation

/// Service for fetching stock prices from Yahoo Finance API
@MainActor
class YahooFinanceService {
    static let shared = YahooFinanceService()

    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Fetch Single Quote

    func fetchQuote(symbol: String) async throws -> StockQuote {
        let urlString = "\(baseURL)\(symbol)?interval=1d&range=5d"
        guard let url = URL(string: urlString) else {
            throw YahooFinanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YahooFinanceError.requestFailed
        }

        return try parseQuote(data: data, symbol: symbol)
    }

    // MARK: - Fetch Multiple Quotes

    func fetchQuotes(symbols: [String]) async -> [String: StockQuote] {
        var results: [String: StockQuote] = [:]

        await withTaskGroup(of: (String, StockQuote?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let quote = try await self.fetchQuote(symbol: symbol)
                        return (symbol, quote)
                    } catch {
                        print("Error fetching \(symbol): \(error)")
                        return (symbol, nil)
                    }
                }
            }

            for await (symbol, quote) in group {
                if let quote = quote {
                    results[symbol] = quote
                }
            }
        }

        return results
    }

    // MARK: - Parse Response

    private func parseQuote(data: Data, symbol: String) throws -> StockQuote {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let meta = result["meta"] as? [String: Any] else {
            throw YahooFinanceError.parseError
        }

        let regularMarketPrice = meta["regularMarketPrice"] as? Double ?? 0
        let previousClose = meta["chartPreviousClose"] as? Double ?? meta["previousClose"] as? Double ?? 0
        let currency = meta["currency"] as? String ?? "USD"
        let exchangeName = meta["exchangeName"] as? String ?? ""
        let shortName = meta["shortName"] as? String ?? symbol

        // Calculate change
        let change = regularMarketPrice - previousClose
        let changePercent = previousClose > 0 ? (change / previousClose) * 100 : 0

        // Get high/low from indicators if available
        var dayHigh: Double?
        var dayLow: Double?

        if let indicators = result["indicators"] as? [String: Any],
           let quote = indicators["quote"] as? [[String: Any]],
           let firstQuote = quote.first {
            if let highs = firstQuote["high"] as? [Double?], let lastHigh = highs.last {
                dayHigh = lastHigh
            }
            if let lows = firstQuote["low"] as? [Double?], let lastLow = lows.last {
                dayLow = lastLow
            }
        }

        return StockQuote(
            symbol: symbol.uppercased(),
            name: shortName,
            price: regularMarketPrice,
            previousClose: previousClose,
            change: change,
            changePercent: changePercent,
            dayHigh: dayHigh,
            dayLow: dayLow,
            currency: currency,
            exchange: exchangeName,
            timestamp: Date()
        )
    }

    // MARK: - Historical Data

    func fetchHistoricalData(symbol: String, range: String = "1y") async throws -> [HistoricalDataPoint] {
        let urlString = "\(baseURL)\(symbol)?interval=1d&range=\(range)"
        guard let url = URL(string: urlString) else {
            throw YahooFinanceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw YahooFinanceError.requestFailed
        }

        return try parseHistoricalData(data: data)
    }

    private func parseHistoricalData(data: Data) throws -> [HistoricalDataPoint] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let results = chart["result"] as? [[String: Any]],
              let result = results.first,
              let timestamps = result["timestamp"] as? [Int],
              let indicators = result["indicators"] as? [String: Any],
              let quote = indicators["quote"] as? [[String: Any]],
              let firstQuote = quote.first else {
            throw YahooFinanceError.parseError
        }

        let closes = firstQuote["close"] as? [Double?] ?? []
        let opens = firstQuote["open"] as? [Double?] ?? []
        let highs = firstQuote["high"] as? [Double?] ?? []
        let lows = firstQuote["low"] as? [Double?] ?? []
        let volumes = firstQuote["volume"] as? [Int?] ?? []

        var dataPoints: [HistoricalDataPoint] = []

        for i in 0..<timestamps.count {
            guard let close = closes[safe: i] ?? nil else { continue }

            let point = HistoricalDataPoint(
                date: Date(timeIntervalSince1970: TimeInterval(timestamps[i])),
                open: opens[safe: i] ?? nil,
                high: highs[safe: i] ?? nil,
                low: lows[safe: i] ?? nil,
                close: close,
                volume: volumes[safe: i] ?? nil
            )
            dataPoints.append(point)
        }

        return dataPoints
    }
}

// MARK: - Data Models

struct StockQuote {
    let symbol: String
    let name: String
    let price: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let dayHigh: Double?
    let dayLow: Double?
    let currency: String
    let exchange: String
    let timestamp: Date

    var isPositive: Bool {
        return change >= 0
    }
}

struct HistoricalDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let open: Double?
    let high: Double?
    let low: Double?
    let close: Double
    let volume: Int?
}

// MARK: - Errors

enum YahooFinanceError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case parseError
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .requestFailed: return "Request failed"
        case .parseError: return "Failed to parse response"
        case .rateLimited: return "Rate limited, please try again later"
        }
    }
}

// MARK: - Array Extension

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
