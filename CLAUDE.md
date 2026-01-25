# AssetMonitor - AI Agent Guide

> **Version**: 1.0.6 | **Updated**: January 25, 2026

## Quick Reference

```
Build:     xcodebuild -project AssetMonitor.xcodeproj -scheme AssetMonitor -configuration Release build
Run:       Cmd+R in Xcode (AssetMonitor scheme)
Database:  ~/Library/Application Support/AssetMonitor/assets.db
App Group: group.JinWookShin.AssetMonitor
```

### Deploy to Applications
```bash
pkill -x "AssetMonitor"
xcodebuild -project AssetMonitor.xcodeproj -scheme AssetMonitor -configuration Release build
rm -rf /Applications/AssetMonitor.app
cp -R ~/Library/Developer/Xcode/DerivedData/AssetMonitor-*/Build/Products/Release/AssetMonitor.app /Applications/
open /Applications/AssetMonitor.app
```

### Create DMG
```bash
# Update MARKETING_VERSION in project.pbxproj first
xcodebuild -project AssetMonitor.xcodeproj -scheme AssetMonitor -configuration Release clean build
rm -rf /tmp/dmg_temp && mkdir -p /tmp/dmg_temp
cp -R ~/Library/Developer/Xcode/DerivedData/AssetMonitor-*/Build/Products/Release/AssetMonitor.app /tmp/dmg_temp/
ln -s /Applications /tmp/dmg_temp/Applications
hdiutil create -volname 'AssetMonitor X.X.X' -srcfolder /tmp/dmg_temp -ov -format UDZO AssetMonitor-X.X.X.dmg
rm -rf /tmp/dmg_temp
```

---

## Project Overview

**AssetMonitor** is a macOS SwiftUI app for personal investment portfolio tracking.

### Features
- Portfolio Tracking (Stocks, ETFs, CDs, Cash)
- Real-time Prices (Yahoo Finance API)
- News Feed (Google News RSS)
- AI Analysis (OpenAI GPT-4)
- DCA Planning
- Widgets & Menu Bar
- Privacy Mode (hide dollar amounts)

### Tech Stack
SwiftUI (macOS 14+) | SQLite | Yahoo Finance | Google News RSS | OpenAI GPT-4 | WidgetKit

---

## Architecture

```
AssetMonitor/
├── App/                    # AssetMonitorApp.swift, Theme.swift, Logger.swift
├── Models/                 # Asset, Transaction, InvestmentPlan
├── Views/                  # All SwiftUI views
├── ViewModels/             # PortfolioViewModel.swift
├── Services/               # DatabaseService, YahooFinance, News, OpenAI
├── AssetMonitorWidgetExtension/  # Widget target
└── Shared/                 # SharedDataManager (App Group data)
```

### Key Singletons
- `DatabaseService.shared` - Database CRUD
- `YahooFinanceService.shared` - Stock prices
- `NewsService.shared` - News fetching
- `OpenAIService.shared` - AI analysis
- `SharedDataManager.shared` - Widget data sync

---

## Database Schema

```sql
-- Assets: id, symbol, type, name, cd_maturity_date, cd_interest_rate, created_at
-- Transactions: id, asset_id, type, date, shares, price_per_share, notes, linked_plan_id, linked_transaction_id, created_at
-- Investment Plans: id, asset_id, total_amount, number_of_purchases, amount_per_purchase, frequency, custom_days_between, start_date, completed_purchases, status, notes, created_at
-- Price Cache: symbol, price, previous_close, change_percent, updated_at
```

---

## Theme System

**Always use Theme constants** - never hardcode colors, spacing, or animations.

```swift
Theme.AssetColors.color(for: assetType)  // stock=blue, etf=green, cd=orange, cash=mint
Theme.StatusColors.positive / .negative / .warning
Theme.Spacing.xs/sm/md/lg/xl  // 4/8/12/16/24
Theme.CornerRadius.small/medium/large  // 4/8/12
Theme.Animation.quick/standard/smooth/spring
.cardStyle() / .elevatedCardStyle()
```

---

## Common Tasks

### Adding Asset Type
1. Add case to `AssetType` in `Asset.swift`
2. Add color in `Theme.AssetColors`
3. Update `AssetsView` add sheet

### Adding View/Tab
1. Add case to `AppTab` in `PortfolioViewModel.swift`
2. Create view in `Views/`
3. Add to `MainView.swift` switch

### Modifying Database
1. Update `createTables()` in `DatabaseService.swift`
2. Add migration for existing users
3. Update model structs and CRUD methods

### Adding Widget Data
1. Add property in `SharedDataManager.swift`
2. Update sync in `PortfolioViewModel.swift`
3. Update widget in `AssetMonitorWidget.swift`

---

## Widget Development

- App Group: `group.JinWookShin.AssetMonitor`
- Main app needs `CODE_SIGN_ENTITLEMENTS = AssetMonitor/AssetMonitor.entitlements`
- Widget types: PortfolioWidget, DCAPlansWidget, StockNewsWidget
- Always use `.lineLimit(1).minimumScaleFactor(0.7)` for text

---

## Debug Commands

```bash
sqlite3 ~/Library/Application\ Support/AssetMonitor/assets.db "SELECT * FROM assets"
rm ~/Library/Application\ Support/AssetMonitor/assets.db  # Reset app
defaults read ~/Library/Group\ Containers/group.JinWookShin.AssetMonitor/Library/Preferences/group.JinWookShin.AssetMonitor
```

---

## Version History

### 1.0.6 (Jan 25, 2026)
- Privacy Mode: hide dollar amounts, show percentages only (Settings or menu bar toggle)
- Widgets and menu bar respect privacy mode

### 1.0.5 (Jan 23, 2026)
- Grouped transaction rows: arrow flows Cash → Buy, type tags on left

### 1.0.4 (Jan 23, 2026)
- Linked transactions (BUY + Cash Withdrawal grouped)
- Total cost input, edit transactions/plans

### 1.0.3 (Jan 23, 2026)
- Widget sync fixes

### 1.0.0 (Jan 2026)
- Initial release

---

## Known Issues

- **PlansView.swift**: "Status" label breaks into two lines. Needs `.lineLimit(1)`.

## Limitations

- Single portfolio only
- No cloud sync
- macOS 14+ required
- English only
