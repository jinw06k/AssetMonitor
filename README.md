# AssetMonitor

A native macOS application for tracking your investment portfolio including stocks, ETFs, CDs, and cash.

![macOS](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![Version](https://img.shields.io/badge/version-1.0.0-green)

## Features

### Portfolio Tracking
- Track stocks, ETFs, certificates of deposit (CDs), and cash
- Real-time price updates from Yahoo Finance
- Daily and total gain/loss calculations
- Interactive pie chart for asset allocation

### Dollar-Cost Averaging (DCA) Plans
- Create investment plans with customizable frequency
- Track progress on scheduled purchases
- Smart timing recommendations based on price trends

### Stock News
- Aggregated news for all your holdings
- Filter by individual stock symbol
- Direct links to full articles

### AI-Powered Analysis
- GPT-4 portfolio analysis and insights
- Risk assessment and diversification suggestions
- Requires OpenAI API key (configured in Settings)

### Desktop Widgets
- Portfolio summary widget
- DCA plans progress widget
- News headlines widget

### Menu Bar Integration
- Quick access to portfolio value
- Daily change indicator
- One-click to open main app

## Installation

### Requirements
- macOS 14.0 (Sonoma) or later
- Internet connection for price updates

### Download
1. Download `AssetMonitor.app` from the releases
2. Move to Applications folder
3. Right-click and select "Open" (first time only, to bypass Gatekeeper)

### Build from Source
```bash
# Clone the repository
git clone <repository-url>
cd AssetMonitor

# Build with Xcode
xcodebuild -scheme AssetMonitor -configuration Release build

# Or open in Xcode
open AssetMonitor.xcodeproj
```

## Getting Started

### Adding Your First Asset

1. Open AssetMonitor
2. Go to the **Assets** tab
3. Click **Add Asset** (+)
4. Select asset type (Stock, ETF, CD, or Cash)
5. Enter the ticker symbol (e.g., AAPL, GOOGL)
6. Click **Add Asset**

### Recording Transactions

1. Go to the **Transactions** tab
2. Click **Add Transaction**
3. Select the asset, type (Buy/Sell), date, shares, and price
4. Click **Add Transaction**

### Setting Up AI Analysis

1. Go to **Settings** (Cmd+,)
2. Navigate to the **API** tab
3. Enter your OpenAI API key
4. Return to the **AI Analysis** tab and click **Generate Analysis**

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Cmd+1 | Dashboard |
| Cmd+2 | Assets |
| Cmd+3 | Transactions |
| Cmd+4 | Plans |
| Cmd+5 | News |
| Cmd+6 | AI Analysis |
| Cmd+R | Refresh Prices |
| Cmd+N | Add New Asset |
| Cmd+, | Settings |

## Data Storage

All data is stored locally on your Mac:
- **Database**: `~/Library/Application Support/AssetMonitor/assets.db`
- **Widget Data**: `~/Library/Group Containers/group.com.assetmonitor.shared/`

### Export Your Data
1. Go to **Settings** > **Data** tab
2. Click **Export Data to CSV** or **Export Data to JSON**
3. Files are saved to your Downloads folder

### Reset All Data
1. Go to **Settings** > **Data** tab
2. Click **Reset All Data** in the Danger Zone
3. Confirm the action (this cannot be undone)

## FAQ

### Why do prices show $0 for some stocks?
- Check your internet connection
- The stock may be delisted or have an invalid symbol
- Yahoo Finance may be temporarily unavailable

### Why is news empty?
- Make sure you have stocks or ETFs added (not just CDs or cash)
- News is fetched from Google News RSS which should always be available

### How do I add widgets to my desktop?
1. Right-click on your desktop
2. Select "Edit Widgets..."
3. Search for "AssetMonitor"
4. Drag the desired widget to your desktop

### Is my data synced to the cloud?
No, all data is stored locally on your Mac. There is no cloud sync feature.

### How much does AI analysis cost?
Each analysis costs approximately $0.03-0.06 depending on portfolio size, charged to your OpenAI account.

## Privacy

- All portfolio data is stored locally on your device
- Stock prices are fetched from Yahoo Finance (public API)
- News is fetched from Google News RSS (public feed)
- AI analysis is sent to OpenAI only when you explicitly request it
- No analytics or tracking is included in the app

## Support

If you encounter issues:
1. Check the FAQ above
2. Try restarting the app
3. Reset data if database is corrupted (Settings > Data > Reset)

## License

Copyright 2026 Jin Wook Shin. All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or modification is strictly prohibited.

---

**AssetMonitor** - Track your investments, plan your future.
