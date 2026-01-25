# Changelog

All notable changes to AssetMonitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] - 2026-01-23

### Improved
- **Grouped Transaction Layout**: Arrow now flows from Cash → Buy, showing money flowing from source to destination
- **Type Tag Position**: "Buy", "Sell", "Deposit", etc. tags now appear on the LEFT of the symbol name for better readability
- **Visual Alignment**: All arrows in grouped transaction rows are center-aligned using fixed-width frames
- **Consistent Styling**: Regular transaction rows now match the tag-left layout of grouped rows

### Technical
- Refactored `GroupedTransactionRowView` with fixed-width frames for alignment
- Updated `TransactionRowView` to place type tag before symbol

---

## [1.0.4] - 2026-01-23

### Added
- **Linked Transactions**: BUY/SELL transactions are now linked with their corresponding Cash Withdrawal/Deposit transactions
- **Grouped Transaction View**: Linked transactions display side-by-side in a single row with an arrow indicator
- **Total Cost Input**: When adding transactions, enter total cost instead of price per share - average price is calculated automatically
- **Edit Transactions**: Right-click context menu to edit existing transactions (date, shares, cost, notes)
- **Edit Investment Plans**: Menu option to modify plan details (total amount, purchases, frequency, start date)
- **Automatic Migration**: Existing BUY and Withdrawal transactions are automatically linked based on matching date, amount, and notes

### Technical
- Added `linkedTransactionId` field to Transaction model
- Added database migration for `linked_transaction_id` column
- Added `updateTransaction()` method to DatabaseService and PortfolioViewModel
- Extended `updateInvestmentPlan()` to update all plan fields (not just status)
- Added `GroupedTransactionRowView` for linked transaction display
- Added `EditTransactionSheet` for modifying transactions
- Added `EditPlanSheet` for modifying investment plans
- Updated `AddTransactionSheet` and `RecordPurchaseSheet` to use total cost input

---

## [1.0.3] - 2026-01-23

### Fixed
- **Widget Sync**: Main app was missing `CODE_SIGN_ENTITLEMENTS` in Xcode build settings, preventing App Groups from working
- **Widget Data**: Added immediate sync on app launch (previously only synced after price refresh)
- **Data Changes**: Widget data now syncs when assets, transactions, or plans are added, updated, or deleted
- **Project Cleanup**: Removed duplicate source files from Views/ subdirectories

### Technical
- Added `CODE_SIGN_ENTITLEMENTS = AssetMonitor/AssetMonitor.entitlements` to main app target (Debug & Release)
- Modified `MainView.swift` to call `syncAllWidgetData()` on launch
- Modified `PortfolioViewModel.swift` to sync after all data mutations

---

## [1.0.2] - 2026-01-22

### Fixed
- Widget UI improvements
- Minor bug fixes

---

## [1.0.0] - 2026-01-22

### Added

#### Portfolio Management
- Track stocks, ETFs, certificates of deposit (CDs), and cash
- Real-time price updates from Yahoo Finance API
- Automatic calculation of total value, gain/loss, and daily changes
- Interactive pie chart for asset allocation visualization
- Portfolio growth chart with 1W/1M/3M time ranges

#### Transaction Tracking
- Record buy, sell, dividend, interest, deposit, and withdrawal transactions
- Automatic cash balance updates when trading
- Transaction history with search and filtering
- Link transactions to DCA investment plans

#### DCA Investment Planning
- Create dollar-cost averaging plans for any asset
- Flexible frequency options: weekly, biweekly, monthly, or custom
- Track progress with completion percentage
- Smart timing recommendations based on price trends
- Visual indicators for overdue purchases

#### Stock News
- Aggregated news from Google News RSS
- Filter by individual stock symbol
- News thumbnails with stock logos
- Direct links to full articles

#### AI-Powered Analysis
- GPT-4 integration for portfolio insights
- Risk assessment and diversification analysis
- Requires user-provided OpenAI API key

#### Desktop Widgets
- Portfolio summary widget (small/medium)
- DCA plans progress widget (medium/large)
- Stock news headlines widget (medium)
- Shared data via App Group

#### Menu Bar Integration
- Quick portfolio value display
- Daily change indicator (green/red)
- One-click access to main app

#### User Interface
- Native macOS design with SwiftUI
- Dark and light mode support
- Keyboard shortcuts for all major actions
- Hover effects and smooth animations

#### Data Management
- Local SQLite database storage
- Export to CSV and JSON
- Price caching for offline access
- Database reset option in settings

### Technical Details
- Minimum requirement: macOS 14.0 (Sonoma)
- Built with SwiftUI and WidgetKit
- Zero external dependencies
- Yahoo Finance API for stock data
- Google News RSS for news (no rate limits)
- OpenAI GPT-4 for AI analysis

---

## Future Releases

### Planned for 1.1.0
- CSV/JSON data import
- Notification alerts for price changes
- Improved dividend tracking

### Planned for 1.2.0
- Multiple portfolio support
- Cloud sync option
- Tax lot tracking

---

## Version Numbering

- **Major (X.0.0)**: Breaking changes or major new features
- **Minor (0.X.0)**: New features, backwards compatible
- **Patch (0.0.X)**: Bug fixes and minor improvements
