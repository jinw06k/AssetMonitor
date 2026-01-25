import SwiftUI

// MARK: - App Theme

/// Centralized theme configuration for AssetMonitor
/// Provides consistent colors, spacing, and styling across the app
enum Theme {

    // MARK: - Asset Type Colors

    enum AssetColors {
        static let stock = Color.blue
        static let etf = Color.purple
        static let treasury = Color.orange
        static let cd = Color.yellow
        static let cash = Color.green

        static func color(for type: AssetType) -> Color {
            switch type {
            case .stock: return stock
            case .etf: return etf
            case .treasury: return treasury
            case .cd: return cd
            case .cash: return cash
            }
        }
    }

    // MARK: - Transaction Type Colors

    enum TransactionColors {
        static let buy = Color.blue
        static let sell = Color.orange
        static let dividend = Color.green
        static let interest = Color.green
        static let deposit = Color.green
        static let withdrawal = Color.red

        static func color(for type: TransactionType) -> Color {
            switch type {
            case .buy: return buy
            case .sell: return sell
            case .dividend: return dividend
            case .interest: return interest
            case .deposit: return deposit
            case .withdrawal: return withdrawal
            }
        }
    }

    // MARK: - Status Colors

    enum StatusColors {
        static let positive = Color.green
        static let negative = Color.red
        static let warning = Color.orange
        static let neutral = Color.secondary
        static let active = Color.blue
        static let paused = Color.orange
        static let completed = Color.green
        static let cancelled = Color.red

        static func color(for status: PlanStatus) -> Color {
            switch status {
            case .active: return active
            case .paused: return paused
            case .completed: return completed
            case .cancelled: return cancelled
            }
        }

        static func changeColor(for value: Double) -> Color {
            if value > 0 { return positive }
            if value < 0 { return negative }
            return neutral
        }
    }

    // MARK: - UI Colors

    enum Colors {
        // Backgrounds
        static var cardBackground: Color {
            Color(NSColor.controlBackgroundColor)
        }

        static var windowBackground: Color {
            Color(NSColor.windowBackgroundColor)
        }

        static var groupedBackground: Color {
            Color(NSColor.underPageBackgroundColor)
        }

        // Text
        static var primaryText: Color {
            Color(NSColor.labelColor)
        }

        static var secondaryText: Color {
            Color(NSColor.secondaryLabelColor)
        }

        static var tertiaryText: Color {
            Color(NSColor.tertiaryLabelColor)
        }

        // Accent
        static var accent: Color {
            Color.accentColor
        }

        // Dividers
        static var divider: Color {
            Color(NSColor.separatorColor)
        }

        // Overlays
        static func overlay(opacity: Double = 0.1) -> Color {
            Color.primary.opacity(opacity)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius

    enum CornerRadius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }

    // MARK: - Shadows

    enum Shadows {
        static func card() -> some View {
            Color.clear
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        }

        static var cardShadow: Color {
            Color.black.opacity(0.1)
        }

        static let cardShadowRadius: CGFloat = 8
    }

    // MARK: - Animation

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.35)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }

    // MARK: - Icon Sizes

    enum IconSize {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xlarge: CGFloat = 24
        static let xxlarge: CGFloat = 32
    }
}

// MARK: - View Extensions

extension View {
    /// Apply standard card styling
    func cardStyle(padding: CGFloat = Theme.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
    }

    /// Apply card styling with shadow
    func elevatedCardStyle(padding: CGFloat = Theme.Spacing.lg) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(color: Theme.Shadows.cardShadow, radius: Theme.Shadows.cardShadowRadius, x: 0, y: 2)
    }

    /// Apply subtle hover effect
    func hoverEffect(isHovered: Bool) -> some View {
        self
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(Theme.Animation.quick, value: isHovered)
    }

    /// Apply loading shimmer effect
    @ViewBuilder
    func shimmer(isActive: Bool) -> some View {
        if isActive {
            self.redacted(reason: .placeholder)
        } else {
            self
        }
    }

    /// Animate number changes
    func animateValue() -> some View {
        self.contentTransition(.numericText())
    }
}

// MARK: - Color Extensions

extension Color {
    /// Create a lighter version of the color
    func lighter(by percentage: CGFloat = 0.2) -> Color {
        self.opacity(1 - percentage)
    }

    /// Create a softer background version of the color
    var softBackground: Color {
        self.opacity(0.15)
    }

    /// Create a subtle tint version
    var subtleTint: Color {
        self.opacity(0.1)
    }
}

// MARK: - Reusable Components

/// A badge view for status indicators
struct StatusBadge: View {
    let text: String
    let color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption2)
            }
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(color.softBackground)
        .foregroundColor(color)
        .cornerRadius(Theme.CornerRadius.small)
    }
}

/// A change indicator showing positive/negative change
struct ChangeIndicator: View {
    let value: Double
    let format: ChangeFormat
    var showIcon: Bool = true
    var font: Font = .caption

    enum ChangeFormat {
        case percent
        case currency
        case number
    }

    private var formattedValue: String {
        switch format {
        case .percent:
            return String(format: "%@%.2f%%", value >= 0 ? "+" : "", value)
        case .currency:
            if value >= 0 {
                return String(format: "+$%.2f", value)
            } else {
                return String(format: "-$%.2f", abs(value))
            }
        case .number:
            return String(format: "%@%.2f", value >= 0 ? "+" : "", value)
        }
    }

    private var color: Color {
        Theme.StatusColors.changeColor(for: value)
    }

    private var iconName: String {
        value >= 0 ? "arrow.up" : "arrow.down"
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if showIcon {
                Image(systemName: iconName)
            }
            Text(formattedValue)
        }
        .font(font)
        .foregroundColor(color)
    }
}

/// A loading placeholder with pulse animation
struct LoadingPlaceholder: View {
    @State private var isAnimating = false
    var height: CGFloat = 20
    var cornerRadius: CGFloat = Theme.CornerRadius.small

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(isAnimating ? 0.3 : 0.15))
            .frame(height: height)
            .animation(
                SwiftUI.Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

/// Empty state view with consistent styling
struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            VStack(spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let action = action, let label = actionLabel {
                Button(action: action) {
                    Text(label)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xxl)
    }
}

/// Section header with consistent styling
struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var action: (() -> Void)? = nil
    var actionLabel: String? = nil

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title)
                    .font(.headline)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let action = action, let label = actionLabel {
                Button(label, action: action)
                    .buttonStyle(.link)
            }
        }
    }
}

// MARK: - Keyboard Shortcut Helpers

extension KeyboardShortcut {
    /// Refresh: Cmd + R
    static let refresh = KeyboardShortcut("r", modifiers: .command)
    /// Add new: Cmd + N
    static let addNew = KeyboardShortcut("n", modifiers: .command)
    /// Search: Cmd + F
    static let search = KeyboardShortcut("f", modifiers: .command)
    /// Dashboard: Cmd + 1
    static let dashboard = KeyboardShortcut("1", modifiers: .command)
    /// Assets: Cmd + 2
    static let assets = KeyboardShortcut("2", modifiers: .command)
    /// Transactions: Cmd + 3
    static let transactions = KeyboardShortcut("3", modifiers: .command)
    /// Plans: Cmd + 4
    static let plans = KeyboardShortcut("4", modifiers: .command)
    /// News: Cmd + 5
    static let news = KeyboardShortcut("5", modifiers: .command)
    /// AI Analysis: Cmd + 6
    static let aiAnalysis = KeyboardShortcut("6", modifiers: .command)
}
