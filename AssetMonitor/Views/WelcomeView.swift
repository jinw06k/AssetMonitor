import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var databaseService: DatabaseService

    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                // Page 1: Welcome
                WelcomePage1()
                    .tag(0)

                // Page 2: Features
                WelcomePage2()
                    .tag(1)

                // Page 3: Get Started
                WelcomePage3(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .tag(2)
            }
            .tabViewStyle(.automatic)

            // Page indicators
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(currentPage == index ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            withAnimation { currentPage = index }
                        }
                }
            }
            .padding(.bottom, Theme.Spacing.xl)

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation { currentPage -= 1 }
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if currentPage < 2 {
                    Button("Next") {
                        withAnimation { currentPage += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxxl)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(width: 600, height: 500)
        .background(Theme.Colors.cardBackground)
    }
}

// MARK: - Page 1: Welcome

struct WelcomePage1: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // App icon
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .blue.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.white)
            }

            VStack(spacing: Theme.Spacing.md) {
                Text("Welcome to AssetMonitor")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your investments, plan your future")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(Theme.Spacing.xxxl)
    }
}

// MARK: - Page 2: Features

struct WelcomePage2: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Text("Everything you need")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, Theme.Spacing.xl)

            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                FeatureItem(
                    icon: "chart.pie.fill",
                    color: .blue,
                    title: "Portfolio Tracking",
                    description: "Monitor stocks, ETFs, CDs, and cash in one place"
                )

                FeatureItem(
                    icon: "calendar.badge.clock",
                    color: .green,
                    title: "DCA Planning",
                    description: "Create and track dollar-cost averaging plans"
                )

                FeatureItem(
                    icon: "newspaper.fill",
                    color: .orange,
                    title: "Stock News",
                    description: "Stay updated with news for your holdings"
                )

                FeatureItem(
                    icon: "brain",
                    color: .purple,
                    title: "AI Analysis",
                    description: "Get GPT-4 powered portfolio insights"
                )
            }
            .padding(.horizontal, Theme.Spacing.xxxl)

            Spacer()
        }
        .padding(Theme.Spacing.xl)
    }
}

struct FeatureItem: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Page 3: Get Started

struct WelcomePage3: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var databaseService: DatabaseService

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            VStack(spacing: Theme.Spacing.md) {
                Text("You're all set!")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Start by adding your first asset")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "1.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Go to the Assets tab")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "2.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Click the + button to add an asset")
                        .foregroundColor(.secondary)
                }

                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "3.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Record your transactions")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)

            Spacer()

            // Skip option for returning users with existing data
            if !databaseService.assets.isEmpty {
                Text("We found existing data from a previous session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(Theme.Spacing.xxxl)
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
        .environmentObject(DatabaseService.shared)
}
