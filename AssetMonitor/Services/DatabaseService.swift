import Foundation
import Combine
import SQLite3

// SQLITE_TRANSIENT tells SQLite to make its own copy of the string
// This is necessary because Swift strings are temporary when passed to C functions
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// DatabaseService handles all SQLite database operations for the app.
/// Uses raw SQLite3 (no external dependencies) for simplicity.
@MainActor
class DatabaseService: ObservableObject {
    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: String

    @Published var assets: [Asset] = []
    @Published var transactions: [Transaction] = []
    @Published var investmentPlans: [InvestmentPlan] = []

    init() {
        // Set up database path
        let fileManager = FileManager.default
        let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDirectory = appSupportURL.appendingPathComponent("AssetMonitor", isDirectory: true)

        // Create directory if needed
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)

        dbPath = appDirectory.appendingPathComponent("assets.db").path

        openDatabase()
        createTables()
        loadAllData()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Database Setup

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("Error opening database: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    private func createTables() {
        let createAssetsTable = """
            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                symbol TEXT NOT NULL,
                type TEXT NOT NULL,
                name TEXT NOT NULL,
                cd_maturity_date TEXT,
                cd_interest_rate REAL,
                created_at TEXT NOT NULL
            );
        """

        let createTransactionsTable = """
            CREATE TABLE IF NOT EXISTS transactions (
                id TEXT PRIMARY KEY,
                asset_id TEXT NOT NULL,
                type TEXT NOT NULL,
                date TEXT NOT NULL,
                shares REAL NOT NULL,
                price_per_share REAL NOT NULL,
                notes TEXT,
                linked_plan_id TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (asset_id) REFERENCES assets(id)
            );
        """

        let createPlansTable = """
            CREATE TABLE IF NOT EXISTS investment_plans (
                id TEXT PRIMARY KEY,
                asset_id TEXT NOT NULL,
                total_amount REAL NOT NULL,
                number_of_purchases INTEGER NOT NULL,
                amount_per_purchase REAL NOT NULL,
                frequency TEXT NOT NULL,
                custom_days_between INTEGER,
                start_date TEXT NOT NULL,
                completed_purchases INTEGER DEFAULT 0,
                status TEXT DEFAULT 'active',
                notes TEXT,
                created_at TEXT NOT NULL,
                FOREIGN KEY (asset_id) REFERENCES assets(id)
            );
        """

        let createPriceCacheTable = """
            CREATE TABLE IF NOT EXISTS price_cache (
                symbol TEXT PRIMARY KEY,
                price REAL NOT NULL,
                previous_close REAL,
                change_percent REAL,
                updated_at TEXT NOT NULL
            );
        """

        executeSQL(createAssetsTable)
        executeSQL(createTransactionsTable)
        executeSQL(createPlansTable)
        executeSQL(createPriceCacheTable)

        // Run migrations
        migrateDatabase()
    }

    private func migrateDatabase() {
        // Add linked_transaction_id column if it doesn't exist
        if !columnExists(table: "transactions", column: "linked_transaction_id") {
            executeSQL("ALTER TABLE transactions ADD COLUMN linked_transaction_id TEXT")
            Logger.debug("Added linked_transaction_id column to transactions table", category: "Database")
        }
    }

    private func columnExists(table: String, column: String) -> Bool {
        let query = "PRAGMA table_info(\(table))"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let columnName = sqlite3_column_text(stmt, 1) {
                    if String(cString: columnName) == column {
                        sqlite3_finalize(stmt)
                        return true
                    }
                }
            }
        }
        sqlite3_finalize(stmt)
        return false
    }

    /// Links existing BUY transactions with their corresponding Cash Withdrawal transactions
    func migrateExistingTransactionLinks() {
        // Find all BUY transactions that don't have a linked transaction
        let buyTransactions = transactions.filter { $0.type == .buy && $0.linkedTransactionId == nil }

        // Get cash asset ID
        guard let cashAsset = assets.first(where: { $0.type == .cash }) else { return }

        for buyTx in buyTransactions {
            // Find matching withdrawal: same date, same amount, notes contain the asset symbol
            guard let asset = getAsset(byId: buyTx.assetId) else { continue }

            let matchingWithdrawal = transactions.first { tx in
                tx.type == .withdrawal &&
                tx.assetId == cashAsset.id &&
                tx.linkedTransactionId == nil &&
                Calendar.current.isDate(tx.date, inSameDayAs: buyTx.date) &&
                abs(tx.totalAmount - buyTx.totalAmount) < 0.01 &&
                (tx.notes?.contains(asset.symbol) ?? false)
            }

            if let withdrawal = matchingWithdrawal {
                // Link them together
                var updatedBuy = buyTx
                var updatedWithdrawal = withdrawal
                updatedBuy.linkedTransactionId = withdrawal.id
                updatedWithdrawal.linkedTransactionId = buyTx.id

                updateTransaction(updatedBuy)
                updateTransaction(updatedWithdrawal)

                Logger.debug("Linked BUY \(buyTx.id) with Withdrawal \(withdrawal.id)", category: "Database")
            }
        }
    }

    private func executeSQL(_ sql: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            if let errMsg = errMsg {
                print("SQL Error: \(String(cString: errMsg))")
                sqlite3_free(errMsg)
            }
        }
    }

    // MARK: - Load Data

    func loadAllData() {
        loadAssets()
        cleanupInvalidAssets()
        consolidateCashAccounts()
        loadTransactions()
        loadInvestmentPlans()
        calculateAssetMetrics()
        migrateExistingTransactionLinks()
    }

    /// Removes invalid assets (blank symbols, "X", test entries)
    private func cleanupInvalidAssets() {
        let invalidAssets = assets.filter { asset in
            let symbol = asset.symbol.trimmingCharacters(in: .whitespacesAndNewlines)
            return symbol.isEmpty || symbol == "X" || symbol.count == 1
        }

        for asset in invalidAssets {
            deleteAsset(asset)
            Logger.debug("Cleaned up invalid asset: '\(asset.symbol)'", category: "Database")
        }
    }

    /// Consolidates multiple cash accounts into a single "CASH" account
    private func consolidateCashAccounts() {
        let cashAssets = assets.filter { $0.type == .cash }

        guard cashAssets.count > 1 else {
            // If only one cash account, just ensure it has the correct symbol
            if let singleCash = cashAssets.first, singleCash.symbol != "CASH" {
                updateAssetSymbol(singleCash.id, newSymbol: "CASH", newName: "Cash")
            }
            return
        }

        Logger.debug("Consolidating \(cashAssets.count) cash accounts into one", category: "Database")

        // Keep the first cash account as the primary one
        let primaryCash = cashAssets[0]
        let otherCashAssets = Array(cashAssets.dropFirst())

        // Move all transactions from other cash accounts to the primary one
        for otherCash in otherCashAssets {
            // Update all transactions to point to the primary cash account
            let updateQuery = "UPDATE transactions SET asset_id = ? WHERE asset_id = ?"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, updateQuery, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, primaryCash.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(stmt, 2, otherCash.id.uuidString, -1, SQLITE_TRANSIENT)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)

            // Delete the other cash asset
            deleteAssetFromDB(otherCash.id)
            Logger.debug("Merged cash account '\(otherCash.symbol)' into primary", category: "Database")
        }

        // Update the primary cash account to have standard symbol/name
        updateAssetSymbol(primaryCash.id, newSymbol: "CASH", newName: "Cash")

        // Reload assets to reflect changes
        loadAssets()
    }

    private func updateAssetSymbol(_ assetId: UUID, newSymbol: String, newName: String) {
        let updateQuery = "UPDATE assets SET symbol = ?, name = ? WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, updateQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, newSymbol, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, newName, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, assetId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    private func deleteAssetFromDB(_ assetId: UUID) {
        let deleteQuery = "DELETE FROM assets WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, assetId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Also remove from in-memory array
        assets.removeAll { $0.id == assetId }
    }

    private func loadAssets() {
        assets.removeAll()
        let query = "SELECT * FROM assets ORDER BY created_at DESC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let asset = assetFromStatement(stmt)
                assets.append(asset)
            }
        }
        sqlite3_finalize(stmt)
    }

    private func loadTransactions() {
        transactions.removeAll()
        let query = "SELECT * FROM transactions ORDER BY date DESC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let transaction = transactionFromStatement(stmt)
                transactions.append(transaction)
            }
        }
        sqlite3_finalize(stmt)
    }

    private func loadInvestmentPlans() {
        investmentPlans.removeAll()
        let query = "SELECT * FROM investment_plans ORDER BY created_at DESC"

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let plan = planFromStatement(stmt)
                investmentPlans.append(plan)
            }
        }
        sqlite3_finalize(stmt)
    }

    private func calculateAssetMetrics() {
        for i in assets.indices {
            let assetTransactions = transactions.filter { $0.assetId == assets[i].id }
            let isCash = assets[i].type == .cash
            let summary = TransactionSummary.calculate(from: assetTransactions, isCash: isCash)
            assets[i].totalShares = summary.totalShares
            assets[i].averageCost = summary.averageCost

            // Load cached price (not for cash)
            if assets[i].type != .cash {
                if let cached = getCachedPrice(for: assets[i].symbol) {
                    assets[i].currentPrice = cached.price
                    assets[i].previousClose = cached.previousClose
                }
            } else {
                // For cash, price is always 1
                assets[i].currentPrice = 1.0
                assets[i].previousClose = 1.0
            }
        }
    }

    // MARK: - Asset CRUD

    func addAsset(_ asset: Asset) {
        let sql = """
            INSERT INTO assets (id, symbol, type, name, cd_maturity_date, cd_interest_rate, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, asset.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, asset.symbol, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, asset.type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, asset.name, -1, SQLITE_TRANSIENT)

            if let maturity = asset.cdMaturityDate {
                sqlite3_bind_text(stmt, 5, ISO8601DateFormatter().string(from: maturity), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            if let rate = asset.cdInterestRate {
                sqlite3_bind_double(stmt, 6, rate)
            } else {
                sqlite3_bind_null(stmt, 6)
            }

            sqlite3_bind_text(stmt, 7, ISO8601DateFormatter().string(from: asset.createdAt), -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.assets.insert(asset, at: 0)
            } else {
                print("Failed to insert asset: \(String(cString: sqlite3_errmsg(db)))")
            }
        } else {
            print("Failed to prepare insert statement: \(String(cString: sqlite3_errmsg(db)))")
        }
        sqlite3_finalize(stmt)
    }

    func updateAsset(_ asset: Asset) {
        let sql = """
            UPDATE assets SET symbol = ?, type = ?, name = ?, cd_maturity_date = ?, cd_interest_rate = ?
            WHERE id = ?
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, asset.symbol, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, asset.type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, asset.name, -1, SQLITE_TRANSIENT)

            if let maturity = asset.cdMaturityDate {
                sqlite3_bind_text(stmt, 4, ISO8601DateFormatter().string(from: maturity), -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            if let rate = asset.cdInterestRate {
                sqlite3_bind_double(stmt, 5, rate)
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            sqlite3_bind_text(stmt, 6, asset.id.uuidString, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                if let index = self.assets.firstIndex(where: { $0.id == asset.id }) {
                    self.assets[index] = asset
                }
            }
        }
        sqlite3_finalize(stmt)
    }

    func deleteAsset(_ asset: Asset) {
        // Delete related transactions first
        let deleteTxSql = "DELETE FROM transactions WHERE asset_id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, deleteTxSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, asset.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Delete related plans
        let deletePlanSql = "DELETE FROM investment_plans WHERE asset_id = ?"
        if sqlite3_prepare_v2(db, deletePlanSql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, asset.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)

        // Delete asset
        let sql = "DELETE FROM assets WHERE id = ?"
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, asset.id.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.assets.removeAll { $0.id == asset.id }
                self.transactions.removeAll { $0.assetId == asset.id }
                self.investmentPlans.removeAll { $0.assetId == asset.id }
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Transaction CRUD

    func addTransaction(_ transaction: Transaction) {
        let sql = """
            INSERT INTO transactions (id, asset_id, type, date, shares, price_per_share, notes, linked_plan_id, created_at, linked_transaction_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, transaction.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, transaction.assetId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 3, transaction.type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 4, ISO8601DateFormatter().string(from: transaction.date), -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 5, transaction.shares)
            sqlite3_bind_double(stmt, 6, transaction.pricePerShare)

            if let notes = transaction.notes {
                sqlite3_bind_text(stmt, 7, notes, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            if let planId = transaction.linkedPlanId {
                sqlite3_bind_text(stmt, 8, planId.uuidString, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 8)
            }

            sqlite3_bind_text(stmt, 9, ISO8601DateFormatter().string(from: transaction.createdAt), -1, SQLITE_TRANSIENT)

            if let linkedTxId = transaction.linkedTransactionId {
                sqlite3_bind_text(stmt, 10, linkedTxId.uuidString, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 10)
            }

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.transactions.insert(transaction, at: 0)
                self.calculateAssetMetrics()
            }
        }
        sqlite3_finalize(stmt)
    }

    func updateTransaction(_ transaction: Transaction) {
        let sql = """
            UPDATE transactions SET type = ?, date = ?, shares = ?, price_per_share = ?, notes = ?, linked_plan_id = ?, linked_transaction_id = ?
            WHERE id = ?
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, transaction.type.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, ISO8601DateFormatter().string(from: transaction.date), -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, transaction.shares)
            sqlite3_bind_double(stmt, 4, transaction.pricePerShare)

            if let notes = transaction.notes {
                sqlite3_bind_text(stmt, 5, notes, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            if let planId = transaction.linkedPlanId {
                sqlite3_bind_text(stmt, 6, planId.uuidString, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 6)
            }

            if let linkedTxId = transaction.linkedTransactionId {
                sqlite3_bind_text(stmt, 7, linkedTxId.uuidString, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            sqlite3_bind_text(stmt, 8, transaction.id.uuidString, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                if let index = self.transactions.firstIndex(where: { $0.id == transaction.id }) {
                    self.transactions[index] = transaction
                }
                self.calculateAssetMetrics()
            }
        }
        sqlite3_finalize(stmt)
    }

    func deleteTransaction(_ transaction: Transaction) {
        let sql = "DELETE FROM transactions WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, transaction.id.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.transactions.removeAll { $0.id == transaction.id }
                self.calculateAssetMetrics()
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Investment Plan CRUD

    func addInvestmentPlan(_ plan: InvestmentPlan) {
        let sql = """
            INSERT INTO investment_plans (id, asset_id, total_amount, number_of_purchases, amount_per_purchase, frequency, custom_days_between, start_date, completed_purchases, status, notes, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, plan.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(stmt, 2, plan.assetId.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 3, plan.totalAmount)
            sqlite3_bind_int(stmt, 4, Int32(plan.numberOfPurchases))
            sqlite3_bind_double(stmt, 5, plan.amountPerPurchase)
            sqlite3_bind_text(stmt, 6, plan.frequency.rawValue, -1, SQLITE_TRANSIENT)

            if let days = plan.customDaysBetween {
                sqlite3_bind_int(stmt, 7, Int32(days))
            } else {
                sqlite3_bind_null(stmt, 7)
            }

            sqlite3_bind_text(stmt, 8, ISO8601DateFormatter().string(from: plan.startDate), -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 9, Int32(plan.completedPurchases))
            sqlite3_bind_text(stmt, 10, plan.status.rawValue, -1, SQLITE_TRANSIENT)

            if let notes = plan.notes {
                sqlite3_bind_text(stmt, 11, notes, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 11)
            }

            sqlite3_bind_text(stmt, 12, ISO8601DateFormatter().string(from: plan.createdAt), -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.investmentPlans.insert(plan, at: 0)
            }
        }
        sqlite3_finalize(stmt)
    }

    func updateInvestmentPlan(_ plan: InvestmentPlan) {
        let sql = """
            UPDATE investment_plans SET
                total_amount = ?,
                number_of_purchases = ?,
                amount_per_purchase = ?,
                frequency = ?,
                custom_days_between = ?,
                start_date = ?,
                completed_purchases = ?,
                status = ?,
                notes = ?
            WHERE id = ?
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_double(stmt, 1, plan.totalAmount)
            sqlite3_bind_int(stmt, 2, Int32(plan.numberOfPurchases))
            sqlite3_bind_double(stmt, 3, plan.amountPerPurchase)
            sqlite3_bind_text(stmt, 4, plan.frequency.rawValue, -1, SQLITE_TRANSIENT)

            if let days = plan.customDaysBetween {
                sqlite3_bind_int(stmt, 5, Int32(days))
            } else {
                sqlite3_bind_null(stmt, 5)
            }

            sqlite3_bind_text(stmt, 6, ISO8601DateFormatter().string(from: plan.startDate), -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(stmt, 7, Int32(plan.completedPurchases))
            sqlite3_bind_text(stmt, 8, plan.status.rawValue, -1, SQLITE_TRANSIENT)

            if let notes = plan.notes {
                sqlite3_bind_text(stmt, 9, notes, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(stmt, 9)
            }

            sqlite3_bind_text(stmt, 10, plan.id.uuidString, -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                if let index = self.investmentPlans.firstIndex(where: { $0.id == plan.id }) {
                    self.investmentPlans[index] = plan
                }
            }
        }
        sqlite3_finalize(stmt)
    }

    func deleteInvestmentPlan(_ plan: InvestmentPlan) {
        let sql = "DELETE FROM investment_plans WHERE id = ?"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, plan.id.uuidString, -1, SQLITE_TRANSIENT)
            if sqlite3_step(stmt) == SQLITE_DONE {
                self.objectWillChange.send()
                self.investmentPlans.removeAll { $0.id == plan.id }
            }
        }
        sqlite3_finalize(stmt)
    }

    // MARK: - Price Cache

    func cachePrice(symbol: String, price: Double, previousClose: Double?, changePercent: Double?) {
        let sql = """
            INSERT OR REPLACE INTO price_cache (symbol, price, previous_close, change_percent, updated_at)
            VALUES (?, ?, ?, ?, ?)
        """

        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, symbol.uppercased(), -1, SQLITE_TRANSIENT)
            sqlite3_bind_double(stmt, 2, price)

            if let prev = previousClose {
                sqlite3_bind_double(stmt, 3, prev)
            } else {
                sqlite3_bind_null(stmt, 3)
            }

            if let change = changePercent {
                sqlite3_bind_double(stmt, 4, change)
            } else {
                sqlite3_bind_null(stmt, 4)
            }

            sqlite3_bind_text(stmt, 5, ISO8601DateFormatter().string(from: Date()), -1, SQLITE_TRANSIENT)
            sqlite3_step(stmt)
        }
        sqlite3_finalize(stmt)
    }

    func getCachedPrice(for symbol: String) -> (price: Double, previousClose: Double?)? {
        let sql = "SELECT price, previous_close FROM price_cache WHERE symbol = ?"
        var stmt: OpaquePointer?

        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, symbol.uppercased(), -1, SQLITE_TRANSIENT)

            if sqlite3_step(stmt) == SQLITE_ROW {
                let price = sqlite3_column_double(stmt, 0)
                let previousClose: Double? = sqlite3_column_type(stmt, 1) != SQLITE_NULL
                    ? sqlite3_column_double(stmt, 1)
                    : nil
                sqlite3_finalize(stmt)
                return (price, previousClose)
            }
        }
        sqlite3_finalize(stmt)
        return nil
    }

    // MARK: - Helper Functions

    private func assetFromStatement(_ stmt: OpaquePointer?) -> Asset {
        let dateFormatter = ISO8601DateFormatter()

        let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
        let symbol = String(cString: sqlite3_column_text(stmt, 1))
        let typeStr = String(cString: sqlite3_column_text(stmt, 2))
        let name = String(cString: sqlite3_column_text(stmt, 3))

        let maturityDate: Date? = sqlite3_column_type(stmt, 4) != SQLITE_NULL
            ? dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 4)))
            : nil

        let interestRate: Double? = sqlite3_column_type(stmt, 5) != SQLITE_NULL
            ? sqlite3_column_double(stmt, 5)
            : nil

        let createdAt = dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 6))) ?? Date()

        return Asset(
            id: id,
            symbol: symbol,
            type: AssetType(rawValue: typeStr) ?? .stock,
            name: name,
            cdMaturityDate: maturityDate,
            cdInterestRate: interestRate,
            createdAt: createdAt
        )
    }

    private func transactionFromStatement(_ stmt: OpaquePointer?) -> Transaction {
        let dateFormatter = ISO8601DateFormatter()

        let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
        let assetId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1))) ?? UUID()
        let typeStr = String(cString: sqlite3_column_text(stmt, 2))
        let date = dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 3))) ?? Date()
        let shares = sqlite3_column_double(stmt, 4)
        let pricePerShare = sqlite3_column_double(stmt, 5)

        let notes: String? = sqlite3_column_type(stmt, 6) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(stmt, 6))
            : nil

        let linkedPlanId: UUID? = sqlite3_column_type(stmt, 7) != SQLITE_NULL
            ? UUID(uuidString: String(cString: sqlite3_column_text(stmt, 7)))
            : nil

        let createdAt = dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 8))) ?? Date()

        // Column 9 is linked_transaction_id (added in migration)
        let linkedTransactionId: UUID? = sqlite3_column_type(stmt, 9) != SQLITE_NULL
            ? UUID(uuidString: String(cString: sqlite3_column_text(stmt, 9)))
            : nil

        return Transaction(
            id: id,
            assetId: assetId,
            type: TransactionType(rawValue: typeStr) ?? .buy,
            date: date,
            shares: shares,
            pricePerShare: pricePerShare,
            notes: notes,
            linkedPlanId: linkedPlanId,
            linkedTransactionId: linkedTransactionId,
            createdAt: createdAt
        )
    }

    private func planFromStatement(_ stmt: OpaquePointer?) -> InvestmentPlan {
        let dateFormatter = ISO8601DateFormatter()

        let id = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 0))) ?? UUID()
        let assetId = UUID(uuidString: String(cString: sqlite3_column_text(stmt, 1))) ?? UUID()
        let totalAmount = sqlite3_column_double(stmt, 2)
        let numberOfPurchases = Int(sqlite3_column_int(stmt, 3))
        let amountPerPurchase = sqlite3_column_double(stmt, 4)
        let frequencyStr = String(cString: sqlite3_column_text(stmt, 5))

        let customDays: Int? = sqlite3_column_type(stmt, 6) != SQLITE_NULL
            ? Int(sqlite3_column_int(stmt, 6))
            : nil

        let startDate = dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 7))) ?? Date()
        let completedPurchases = Int(sqlite3_column_int(stmt, 8))
        let statusStr = String(cString: sqlite3_column_text(stmt, 9))

        let notes: String? = sqlite3_column_type(stmt, 10) != SQLITE_NULL
            ? String(cString: sqlite3_column_text(stmt, 10))
            : nil

        // createdAt is stored but not used when loading (InvestmentPlan.init sets it)
        _ = dateFormatter.date(from: String(cString: sqlite3_column_text(stmt, 11))) ?? Date()

        var plan = InvestmentPlan(
            id: id,
            assetId: assetId,
            totalAmount: totalAmount,
            numberOfPurchases: numberOfPurchases,
            frequency: PlanFrequency(rawValue: frequencyStr) ?? .monthly,
            customDaysBetween: customDays,
            startDate: startDate,
            notes: notes
        )
        plan.amountPerPurchase = amountPerPurchase
        plan.completedPurchases = completedPurchases
        plan.status = PlanStatus(rawValue: statusStr) ?? .active
        return plan
    }

    // MARK: - Query Helpers

    func getTransactions(for assetId: UUID) -> [Transaction] {
        return transactions.filter { $0.assetId == assetId }
    }

    func getPlans(for assetId: UUID) -> [InvestmentPlan] {
        return investmentPlans.filter { $0.assetId == assetId }
    }

    func getAsset(byId id: UUID) -> Asset? {
        return assets.first { $0.id == id }
    }

    func getAsset(bySymbol symbol: String) -> Asset? {
        return assets.first { $0.symbol.uppercased() == symbol.uppercased() }
    }
}
