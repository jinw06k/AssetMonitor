import SwiftUI
import Combine

/// Manages the menu bar icon and state
@MainActor
class MenuBarManager: ObservableObject {
    @Published var iconName: String = "chart.line.uptrend.xyaxis"

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Update icon based on daily change
        // Green arrow up for positive, red arrow down for negative
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateIcon()
            }
            .store(in: &cancellables)
    }

    func updateIcon() {
        let dailyChange = DatabaseService.shared.assets.reduce(0.0) { total, asset in
            total + (asset.totalShares * asset.dailyChange)
        }

        if dailyChange > 0 {
            iconName = "chart.line.uptrend.xyaxis"
        } else if dailyChange < 0 {
            iconName = "chart.line.downtrend.xyaxis"
        } else {
            iconName = "chart.line.flattrend.xyaxis"
        }
    }
}
