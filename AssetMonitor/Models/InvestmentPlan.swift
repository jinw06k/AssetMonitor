import Foundation

enum PlanFrequency: String, Codable, CaseIterable {
    case weekly = "weekly"
    case biweekly = "biweekly"
    case monthly = "monthly"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .biweekly: return "Bi-weekly"
        case .monthly: return "Monthly"
        case .custom: return "Custom"
        }
    }

    var daysBetween: Int {
        switch self {
        case .weekly: return 7
        case .biweekly: return 14
        case .monthly: return 30
        case .custom: return 0
        }
    }
}

enum PlanStatus: String, Codable, CaseIterable {
    case active = "active"
    case paused = "paused"
    case completed = "completed"
    case cancelled = "cancelled"

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "play.circle.fill"
        case .paused: return "pause.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

struct InvestmentPlan: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    let assetId: UUID
    var totalAmount: Double
    var numberOfPurchases: Int
    var amountPerPurchase: Double
    var frequency: PlanFrequency
    var customDaysBetween: Int?
    var startDate: Date
    var completedPurchases: Int
    var status: PlanStatus
    var notes: String?
    var createdAt: Date

    // Computed properties
    var progressPercent: Double {
        guard numberOfPurchases > 0 else { return 0 }
        return Double(completedPurchases) / Double(numberOfPurchases) * 100
    }

    var remainingPurchases: Int {
        return max(numberOfPurchases - completedPurchases, 0)
    }

    var remainingAmount: Double {
        return Double(remainingPurchases) * amountPerPurchase
    }

    var investedAmount: Double {
        return Double(completedPurchases) * amountPerPurchase
    }

    var nextPurchaseDate: Date? {
        guard status == .active, completedPurchases < numberOfPurchases else { return nil }

        let days = frequency == .custom ? (customDaysBetween ?? 0) : frequency.daysBetween
        let calendar = Calendar.current

        if completedPurchases == 0 {
            return startDate
        }

        return calendar.date(byAdding: .day, value: days * completedPurchases, to: startDate)
    }

    var isOverdue: Bool {
        guard let nextDate = nextPurchaseDate else { return false }
        return nextDate < Date()
    }

    init(
        id: UUID = UUID(),
        assetId: UUID,
        totalAmount: Double,
        numberOfPurchases: Int,
        frequency: PlanFrequency,
        customDaysBetween: Int? = nil,
        startDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.assetId = assetId
        self.totalAmount = totalAmount
        self.numberOfPurchases = numberOfPurchases
        self.amountPerPurchase = totalAmount / Double(numberOfPurchases)
        self.frequency = frequency
        self.customDaysBetween = customDaysBetween
        self.startDate = startDate
        self.completedPurchases = 0
        self.status = .active
        self.notes = notes
        self.createdAt = Date()
    }

    mutating func recordPurchase() {
        guard completedPurchases < numberOfPurchases else { return }
        completedPurchases += 1

        if completedPurchases >= numberOfPurchases {
            status = .completed
        }
    }

    mutating func pause() {
        guard status == .active else { return }
        status = .paused
    }

    mutating func resume() {
        guard status == .paused else { return }
        status = .active
    }

    mutating func cancel() {
        status = .cancelled
    }
}

// MARK: - Plan Schedule Item
struct PlanScheduleItem: Identifiable {
    let id = UUID()
    let purchaseNumber: Int
    let scheduledDate: Date
    let amount: Double
    let isCompleted: Bool
    let isOverdue: Bool
}

extension InvestmentPlan {
    var schedule: [PlanScheduleItem] {
        let days = frequency == .custom ? (customDaysBetween ?? 0) : frequency.daysBetween
        let calendar = Calendar.current
        let now = Date()

        return (0..<numberOfPurchases).map { index in
            let date = calendar.date(byAdding: .day, value: days * index, to: startDate) ?? startDate
            let isCompleted = index < completedPurchases
            let isOverdue = !isCompleted && date < now

            return PlanScheduleItem(
                purchaseNumber: index + 1,
                scheduledDate: date,
                amount: amountPerPurchase,
                isCompleted: isCompleted,
                isOverdue: isOverdue
            )
        }
    }
}
