# AssetMonitor - Developer Guide

This guide covers everything you need to know to develop, maintain, and extend AssetMonitor.

## Development Setup

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Apple Developer account (for code signing, optional for local dev)

### Getting Started

```bash
# Clone the repository
git clone <repository-url>
cd AssetMonitor

# Open in Xcode
open AssetMonitor.xcodeproj

# Or build from command line
xcodebuild -scheme AssetMonitor -configuration Debug build
```

### Running the App
1. Open `AssetMonitor.xcodeproj` in Xcode
2. Select the "AssetMonitor" scheme (not the widget scheme)
3. Press Cmd+R to build and run

### Running Widgets
1. Select "AssetMonitorWidgetExtensionExtension" scheme
2. Press Cmd+R
3. Choose a widget size in the simulator

## Project Architecture

### Targets
| Target | Purpose |
|--------|---------|
| AssetMonitor | Main application |
| AssetMonitorWidgetExtensionExtension | WidgetKit extension |

### Dependencies
This project uses **zero external dependencies**. All functionality is implemented using:
- SwiftUI (UI framework)
- Raw SQLite3 (database)
- URLSession (networking)
- XMLParser (RSS parsing)
- WidgetKit (widgets)

### Code Organization

```
AssetMonitor/
├── App/           # Application entry, configuration
├── Models/        # Data models, enums
├── Views/         # SwiftUI views
├── ViewModels/    # ObservableObject state management
├── Services/      # Business logic, API calls, database
└── Assets.xcassets/  # Images, colors
```

## Key Components

### Models

#### Asset.swift
```swift
struct Asset: Identifiable, Codable {
    let id: UUID
    var symbol: String
    var type: AssetType      // .stock, .etf, .cd, .cash
    var name: String
    var totalShares: Double  // Calculated from transactions
    var averageCost: Double  // Calculated from transactions
    var currentPrice: Double?
    var previousClose: Double?
    // CD-specific
    var cdMaturityDate: Date?
    var cdInterestRate: Double?
}

enum AssetType: String, Codable, CaseIterable {
    case stock, etf, cd, cash
}
```

#### Transaction.swift
```swift
struct Transaction: Identifiable, Codable {
    let id: UUID
    let assetId: UUID
    let type: TransactionType
    let date: Date
    let shares: Double
    let pricePerShare: Double
    var notes: String?
    var linkedPlanId: UUID?
}

enum TransactionType: String, Codable {
    case buy, sell, dividend, interest, deposit, withdrawal
}
```

#### InvestmentPlan.swift
```swift
struct InvestmentPlan: Identifiable, Codable {
    let id: UUID
    let assetId: UUID
    let totalAmount: Double
    let numberOfPurchases: Int
    var amountPerPurchase: Double
    let frequency: PlanFrequency
    var customDaysBetween: Int?
    let startDate: Date
    var completedPurchases: Int
    var status: PlanStatus
}
```

### Services

#### DatabaseService
- Singleton: `DatabaseService.shared`
- Uses raw SQLite3 (no ORM)
- Publishes: `assets`, `transactions`, `investmentPlans`
- Auto-calculates asset metrics from transactions
- Caches prices for offline use

#### YahooFinanceService
- Singleton: `YahooFinanceService.shared`
- Fetches real-time stock quotes
- Fetches historical data for charts
- No API key required

#### NewsService
- Singleton: `NewsService.shared`
- Uses Google News RSS (free, no limits)
- Parses XML with XMLParser
- Provides timing analysis for DCA

#### OpenAIService
- Singleton: `OpenAIService.shared`
- Requires user-provided API key
- Uses GPT-4 model
- Generates portfolio analysis

### ViewModel

#### PortfolioViewModel
The main state container for the app:
```swift
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var selectedTab: AppTab = .dashboard
    @Published var stockNews: [StockNews] = []
    @Published var aiAnalysis: PortfolioAnalysis?

    // Computed properties for portfolio calculations
    var totalPortfolioValue: Double
    var totalGainLoss: Double
    var dailyChange: Double
    // etc.
}
```

## Theme System

All styling should use the Theme system. Never hardcode values.

### Usage Examples
```swift
// Colors
Theme.AssetColors.color(for: asset.type)
Theme.StatusColors.positive

// Spacing
.padding(Theme.Spacing.md)
VStack(spacing: Theme.Spacing.sm)

// Corner radius
.cornerRadius(Theme.CornerRadius.large)

// Animations
withAnimation(Theme.Animation.quick) { }
.animation(Theme.Animation.standard, value: state)

// View modifiers
.cardStyle()
.elevatedCardStyle()
```

## Database

### Schema
Located in `DatabaseService.createTables()`. See CLAUDE.md for full schema.

### Migrations
Currently no migration system. For schema changes:
1. Update `createTables()` for new installs
2. Add ALTER TABLE statements for existing users
3. Wrap in version checks if needed

### Testing Database
```bash
# Open database
sqlite3 ~/Library/Application\ Support/AssetMonitor/assets.db

# Common queries
.tables
.schema assets
SELECT * FROM assets;
SELECT * FROM transactions WHERE asset_id = 'uuid';

# Reset database
rm ~/Library/Application\ Support/AssetMonitor/assets.db
```

## Widget Development

### App Group
The app and widget share data via App Group:
- ID: `group.com.assetmonitor.shared`
- Both targets must have this in entitlements

### SharedDataManager
Handles data synchronization:
```swift
// In main app
SharedDataManager.shared.syncFromMainApp(assets: assets)
SharedDataManager.shared.syncNews(news: news)

// In widget
let data = SharedDataManager.shared.loadPortfolioData()
```

### Widget Types
1. **PortfolioWidget** - Shows total value and daily change
2. **DCAPlansWidget** - Shows active investment plans
3. **StockNewsWidget** - Shows recent news headlines

### Timeline Updates
Widgets refresh every 15 minutes via `TimelineReloadPolicy.after(Date().addingTimeInterval(15 * 60))`

## API Integration

### Yahoo Finance
```swift
// Endpoint
GET https://query1.finance.yahoo.com/v8/finance/chart/{symbol}

// Query params for historical
?interval=1d&range=1mo

// Response parsing in YahooFinanceService.swift
```

### Google News RSS
```swift
// Endpoint
GET https://news.google.com/rss/search?q={symbol}+stock&hl=en-US&gl=US&ceid=US:en

// Response: RSS XML
// Parsed using XMLParser in NewsService.swift
```

### OpenAI
```swift
// Endpoint
POST https://api.openai.com/v1/chat/completions

// Headers
Authorization: Bearer {API_KEY}
Content-Type: application/json

// Body
{
    "model": "gpt-4",
    "messages": [...]
}
```

## Testing

### Manual Testing Checklist
- [ ] Add stock/ETF and verify price loads
- [ ] Add CD with maturity date
- [ ] Add cash and record deposit/withdrawal
- [ ] Create buy/sell transactions
- [ ] Create DCA plan and record purchase
- [ ] Check news loads for holdings
- [ ] Test AI analysis (requires API key)
- [ ] Verify widgets display data
- [ ] Test menu bar functionality
- [ ] Test all keyboard shortcuts

### Debug Mode
Use `Logger` for debug output:
```swift
Logger.debug("Message", category: "Category")  // Only in DEBUG
Logger.error("Error", category: "Category")    // Always logs
```

## Build & Release

### Debug Build
```bash
xcodebuild -scheme AssetMonitor -configuration Debug build
```

### Release Build
```bash
xcodebuild -scheme AssetMonitor -configuration Release build
```

### Archive for Distribution
1. In Xcode: Product > Archive
2. Select archive in Organizer
3. Distribute App > Copy App (for direct distribution)

### Code Signing
- For personal use: Sign with development certificate
- For distribution: Requires Developer ID certificate ($99/year Apple Developer Program)
- Without signing: Users must right-click > Open to bypass Gatekeeper

## Code Style

### Swift
- Use `@MainActor` for UI classes
- Use `async/await` for async operations
- Prefer `guard let` for early returns
- Use `// MARK: -` for section headers

### SwiftUI
- Keep views focused and small
- Extract reusable components
- Use environment objects for shared state
- Always use Theme constants

### Naming Conventions
- Views: `*View.swift`
- ViewModels: `*ViewModel.swift`
- Services: `*Service.swift`
- Models: Singular noun (e.g., `Asset.swift`)

## Troubleshooting

### Build Errors
| Error | Solution |
|-------|----------|
| Signing issues | Select team in project settings |
| Widget not building | Check App Group in both targets |
| Missing module | Clean build folder (Cmd+Shift+K) |

### Runtime Issues
| Issue | Solution |
|-------|----------|
| Prices not loading | Check network, may be rate limited |
| Widget empty | Verify App Group data sync |
| Database errors | Delete database file and restart |

### Debug Commands
```bash
# View console logs
log stream --predicate 'subsystem == "com.assetmonitor"'

# Check App Group
ls ~/Library/Group\ Containers/group.com.assetmonitor.shared/

# Reset everything
rm -rf ~/Library/Application\ Support/AssetMonitor/
rm -rf ~/Library/Group\ Containers/group.com.assetmonitor.shared/
```

## Contributing

1. Create a feature branch
2. Make changes following code style guidelines
3. Test thoroughly using the manual testing checklist
4. Update documentation if needed
5. Submit for review

## Resources

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [WidgetKit Documentation](https://developer.apple.com/documentation/widgetkit)
- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [Yahoo Finance API (unofficial)](https://github.com/ranaroussi/yfinance)
- [OpenAI API Documentation](https://platform.openai.com/docs)
