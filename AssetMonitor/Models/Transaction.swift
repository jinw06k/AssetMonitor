import Foundation

enum TransactionType: String, Codable, CaseIterable {
    case buy = "buy"
    case sell = "sell"
    case dividend = "dividend"
    case interest = "interest"
    case deposit = "deposit"
    case withdrawal = "withdrawal"

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .dividend: return "Dividend"
        case .interest: return "Interest"
        case .deposit: return "Deposit"
        case .withdrawal: return "Withdrawal"
        }
    }

    var iconName: String {
        switch self {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .dividend: return "dollarsign.circle.fill"
        case .interest: return "percent"
        case .deposit: return "plus.circle.fill"
        case .withdrawal: return "minus.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .buy: return "blue"
        case .sell: return "orange"
        case .dividend, .interest, .deposit: return "green"
        case .withdrawal: return "red"
        }
    }

    /// Transaction types for trading assets
    static var tradingTypes: [TransactionType] {
        return [.buy, .sell, .dividend, .interest]
    }

    /// Transaction types for cash
    static var cashTypes: [TransactionType] {
        return [.deposit, .withdrawal]
    }
}

struct Transaction: Identifiable, Codable {
    let id: UUID
    let assetId: UUID
    var type: TransactionType
    var date: Date
    var shares: Double
    var pricePerShare: Double
    var notes: String?
    var linkedPlanId: UUID?  // If this transaction is part of a DCA plan
    var linkedTransactionId: UUID?  // Links BUY with corresponding Cash Withdrawal
    var createdAt: Date

    var totalAmount: Double {
        return shares * pricePerShare
    }

    init(
        id: UUID = UUID(),
        assetId: UUID,
        type: TransactionType,
        date: Date = Date(),
        shares: Double,
        pricePerShare: Double,
        notes: String? = nil,
        linkedPlanId: UUID? = nil,
        linkedTransactionId: UUID? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assetId = assetId
        self.type = type
        self.date = date
        self.shares = shares
        self.pricePerShare = pricePerShare
        self.notes = notes
        self.linkedPlanId = linkedPlanId
        self.linkedTransactionId = linkedTransactionId
        self.createdAt = createdAt
    }
}

// MARK: - Transaction Summary
struct TransactionSummary {
    let totalShares: Double  // For cash assets, this represents the balance
    let averageCost: Double
    let totalInvested: Double
    let totalDividends: Double
    let realizedGains: Double

    static func calculate(from transactions: [Transaction], isCash: Bool = false) -> TransactionSummary {
        var shares: Double = 0
        var totalCost: Double = 0
        var totalDividends: Double = 0
        var realizedGains: Double = 0

        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            switch transaction.type {
            case .buy:
                totalCost += transaction.totalAmount
                shares += transaction.shares
            case .sell:
                let costBasis = shares > 0 ? (totalCost / shares) * transaction.shares : 0
                realizedGains += transaction.totalAmount - costBasis
                totalCost -= costBasis
                shares -= transaction.shares
            case .dividend, .interest:
                totalDividends += transaction.totalAmount
            case .deposit:
                // For cash: deposit adds to balance
                shares += transaction.totalAmount
                totalCost += transaction.totalAmount
            case .withdrawal:
                // For cash: withdrawal reduces balance
                shares -= transaction.totalAmount
                totalCost -= transaction.totalAmount
            }
        }

        let averageCost = isCash ? 1.0 : (shares > 0 ? totalCost / shares : 0)

        return TransactionSummary(
            totalShares: max(shares, 0),
            averageCost: averageCost,
            totalInvested: totalCost,
            totalDividends: totalDividends,
            realizedGains: realizedGains
        )
    }
}
