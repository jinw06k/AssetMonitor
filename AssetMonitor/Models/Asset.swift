import Foundation

enum AssetType: String, Codable, CaseIterable {
    case stock = "stock"
    case etf = "etf"
    case treasury = "treasury"
    case cd = "cd"
    case cash = "cash"

    var displayName: String {
        switch self {
        case .stock: return "Stock"
        case .etf: return "ETF"
        case .treasury: return "Treasury"
        case .cd: return "CD"
        case .cash: return "Cash"
        }
    }

    var iconName: String {
        switch self {
        case .stock: return "chart.line.uptrend.xyaxis"
        case .etf: return "chart.pie.fill"
        case .treasury: return "building.columns"
        case .cd: return "banknote.fill"
        case .cash: return "dollarsign.circle.fill"
        }
    }

    /// Asset types that can be traded (not cash)
    static var tradableTypes: [AssetType] {
        return [.stock, .etf, .treasury, .cd]
    }
}

struct Asset: Identifiable, Codable, Hashable {
    let id: UUID
    var symbol: String
    var type: AssetType
    var name: String
    var cdMaturityDate: Date?
    var cdInterestRate: Double?
    var createdAt: Date

    // Computed from transactions (not stored)
    var totalShares: Double = 0
    var averageCost: Double = 0
    var currentPrice: Double?
    var previousClose: Double?

    var totalValue: Double {
        // For cash, totalShares represents the cash balance
        if type == .cash {
            return totalShares
        }
        guard let price = currentPrice else { return totalShares * averageCost }
        return totalShares * price
    }

    var totalCost: Double {
        return totalShares * averageCost
    }

    var gainLoss: Double {
        return totalValue - totalCost
    }

    var gainLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (gainLoss / totalCost) * 100
    }

    var dailyChange: Double {
        guard let current = currentPrice, let previous = previousClose else { return 0 }
        return current - previous
    }

    var dailyChangePercent: Double {
        guard let current = currentPrice, let previous = previousClose, previous > 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }

    init(
        id: UUID = UUID(),
        symbol: String,
        type: AssetType,
        name: String,
        cdMaturityDate: Date? = nil,
        cdInterestRate: Double? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.type = type
        self.name = name
        self.cdMaturityDate = cdMaturityDate
        self.cdInterestRate = cdInterestRate
        self.createdAt = createdAt
    }

    // For CD assets: calculate current value with interest
    var cdCurrentValue: Double? {
        guard type == .cd,
              let rate = cdInterestRate,
              let maturity = cdMaturityDate else { return nil }

        let principal = totalCost
        let now = Date()
        let totalDays = maturity.timeIntervalSince(createdAt) / 86400
        let elapsedDays = now.timeIntervalSince(createdAt) / 86400

        guard totalDays > 0 else { return principal }

        let progress = min(elapsedDays / totalDays, 1.0)
        let earnedInterest = principal * (rate / 100) * progress

        return principal + earnedInterest
    }
}

// MARK: - Predefined Assets
extension Asset {
    static let popularStocks: [(symbol: String, name: String)] = [
        ("AAPL", "Apple Inc."),
        ("GOOGL", "Alphabet Inc."),
        ("AMZN", "Amazon.com Inc."),
        ("TSLA", "Tesla Inc."),
        ("NVDA", "NVIDIA Corporation"),
        ("MSFT", "Microsoft Corporation"),
        ("META", "Meta Platforms Inc."),
        ("NFLX", "Netflix Inc.")
    ]

    static let popularETFs: [(symbol: String, name: String)] = [
        ("SPY", "SPDR S&P 500 ETF"),
        ("QQQ", "Invesco QQQ Trust"),
        ("VOO", "Vanguard S&P 500 ETF"),
        ("VTI", "Vanguard Total Stock Market ETF"),
        ("IWM", "iShares Russell 2000 ETF"),
        ("DIA", "SPDR Dow Jones Industrial Average ETF"),
        ("VGT", "Vanguard Information Technology ETF")
    ]

    static let popularTreasuries: [(symbol: String, name: String)] = [
        ("SGOV", "iShares 0-3 Month Treasury Bond ETF"),
        ("BIL", "SPDR Bloomberg 1-3 Month T-Bill ETF"),
        ("SHV", "iShares Short Treasury Bond ETF"),
        ("SHY", "iShares 1-3 Year Treasury Bond ETF"),
        ("IEF", "iShares 7-10 Year Treasury Bond ETF"),
        ("TLT", "iShares 20+ Year Treasury Bond ETF")
    ]
}
