import Foundation

struct WatchlistItem: Identifiable, Codable {
    let id: UUID
    var symbol: String
    var name: String
    var addedAt: Date

    // Runtime-only (not persisted)
    var currentPrice: Double?
    var previousClose: Double?

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
        name: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.addedAt = addedAt
    }
}
