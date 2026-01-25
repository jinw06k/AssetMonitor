import SwiftUI

@main
struct AssetMonitorApp: App {
    @StateObject private var databaseService = DatabaseService.shared
    @StateObject private var portfolioViewModel = PortfolioViewModel()
    @StateObject private var menuBarManager = MenuBarManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainView()
                    .environmentObject(databaseService)
                    .environmentObject(portfolioViewModel)
                    .frame(minWidth: 900, minHeight: 600)
            } else {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(databaseService)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra("AssetMonitor", systemImage: menuBarManager.iconName) {
            MenuBarView()
                .environmentObject(databaseService)
                .environmentObject(portfolioViewModel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(databaseService)
                .environmentObject(portfolioViewModel)
        }
    }
}
