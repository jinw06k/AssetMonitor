import SwiftUI

struct PlansView: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService

    @State private var showingAddSheet = false
    @State private var filterStatus: PlanStatus?
    @State private var selectedPlan: InvestmentPlan?

    var filteredPlans: [InvestmentPlan] {
        var plans = databaseService.investmentPlans

        if let status = filterStatus {
            plans = plans.filter { $0.status == status }
        }

        return plans.sorted { p1, p2 in
            // Active plans first, then by date
            if p1.status == .active && p2.status != .active { return true }
            if p1.status != .active && p2.status == .active { return false }
            return p1.startDate > p2.startDate
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                // Filter by status
                Picker("Status", selection: $filterStatus) {
                    Text("All Plans").tag(nil as PlanStatus?)
                    ForEach(PlanStatus.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status as PlanStatus?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 400)

                Spacer()

                Button(action: { showingAddSheet = true }) {
                    Label("New Plan", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Summary
            HStack(spacing: 24) {
                PlanSummaryCard(
                    title: "Active Plans",
                    count: databaseService.investmentPlans.filter { $0.status == .active }.count,
                    totalAmount: databaseService.investmentPlans.filter { $0.status == .active }.reduce(0) { $0 + $1.remainingAmount },
                    color: Theme.StatusColors.active
                )

                PlanSummaryCard(
                    title: "Overdue",
                    count: viewModel.overduePlans.count,
                    totalAmount: viewModel.overduePlans.reduce(0) { $0 + $1.amountPerPurchase },
                    color: Theme.StatusColors.warning
                )

                PlanSummaryCard(
                    title: "Completed",
                    count: databaseService.investmentPlans.filter { $0.status == .completed }.count,
                    totalAmount: databaseService.investmentPlans.filter { $0.status == .completed }.reduce(0) { $0 + $1.totalAmount },
                    color: Theme.StatusColors.completed
                )

                Spacer()
            }
            .padding()

            Divider()

            // Plans List
            if filteredPlans.isEmpty {
                ContentUnavailableView(
                    "No Investment Plans",
                    systemImage: "calendar.badge.clock",
                    description: Text("Create a DCA plan to invest consistently over time")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredPlans) { plan in
                            PlanCardView(plan: plan, onSelect: { selectedPlan = plan })
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddPlanSheet()
        }
        .sheet(item: $selectedPlan) { plan in
            PlanDetailSheet(plan: plan)
        }
    }
}

// MARK: - Plan Summary Card

struct PlanSummaryCard: View {
    let title: String
    let count: Int
    let totalAmount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
            Text(totalAmount, format: .currency(code: "USD"))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Plan Card View

struct PlanCardView: View {
    let plan: InvestmentPlan
    let onSelect: () -> Void

    @EnvironmentObject var databaseService: DatabaseService
    @EnvironmentObject var viewModel: PortfolioViewModel

    @State private var showingRecordPurchaseSheet = false
    @State private var showingEditSheet = false

    var asset: Asset? {
        databaseService.getAsset(byId: plan.assetId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(asset?.symbol ?? "Unknown")
                            .font(.headline)
                        Text(asset?.name ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Image(systemName: plan.status.iconName)
                        Text(plan.status.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(Theme.StatusColors.color(for: plan.status))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(plan.remainingAmount, format: .currency(code: "USD"))
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ProgressView(value: plan.progressPercent, total: 100)
                    .tint(plan.isOverdue ? Theme.StatusColors.warning : Theme.StatusColors.active)

                HStack {
                    Text("\(plan.completedPurchases) of \(plan.numberOfPurchases) purchases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(plan.progressPercent, specifier: "%.0f")% complete")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Next purchase info
            if plan.status == .active {
                HStack {
                    if plan.isOverdue {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.StatusColors.warning)
                            Text("Purchase overdue!")
                                .foregroundColor(Theme.StatusColors.warning)
                        }
                    } else if let nextDate = plan.nextPurchaseDate {
                        Text("Next: \(nextDate, style: .date)")
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(plan.amountPerPurchase, format: .currency(code: "USD")) per purchase")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            // Actions
            HStack {
                Button("View Details") {
                    onSelect()
                }
                .buttonStyle(.bordered)

                Spacer()

                if plan.status == .active {
                    Button("Record Purchase") {
                        showingRecordPurchaseSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }

                Menu {
                    Button("Edit Plan") {
                        showingEditSheet = true
                    }

                    if plan.status == .active {
                        Button("Pause Plan") {
                            var updatedPlan = plan
                            updatedPlan.pause()
                            viewModel.updatePlan(updatedPlan)
                        }
                    }
                    if plan.status == .paused {
                        Button("Resume Plan") {
                            var updatedPlan = plan
                            updatedPlan.resume()
                            viewModel.updatePlan(updatedPlan)
                        }
                    }
                    Divider()
                    Button("Delete Plan", role: .destructive) {
                        viewModel.deletePlan(plan)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding()
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.CornerRadius.large)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                .stroke(plan.isOverdue ? Theme.StatusColors.warning.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .sheet(isPresented: $showingRecordPurchaseSheet) {
            if let asset = asset {
                RecordPurchaseSheet(plan: plan, asset: asset)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let asset = asset {
                EditPlanSheet(plan: plan, asset: asset)
            }
        }
    }
}

// MARK: - Record Purchase Sheet

struct RecordPurchaseSheet: View {
    let plan: InvestmentPlan
    let asset: Asset

    @EnvironmentObject var viewModel: PortfolioViewModel
    @Environment(\.dismiss) var dismiss

    @State private var sharesText = ""
    @State private var totalCostText = ""
    @State private var date = Date()
    @State private var notes = ""
    @State private var isLoadingPrice = false
    @State private var currentPrice: Double?

    var shares: Double {
        Double(sharesText) ?? 0
    }

    var totalCost: Double {
        Double(totalCostText) ?? 0
    }

    var pricePerShare: Double {
        guard shares > 0 else { return 0 }
        return totalCost / shares
    }

    var suggestedShares: Double {
        guard let price = currentPrice, price > 0 else { return 0 }
        return plan.amountPerPurchase / price
    }

    var isValid: Bool {
        shares > 0 && totalCost > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Record Purchase")
                        .font(.headline)
                    Text("\(asset.symbol) - DCA Plan")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            Form {
                Section("Plan Info") {
                    HStack {
                        Text("Purchase #")
                        Spacer()
                        Text("\(plan.completedPurchases + 1) of \(plan.numberOfPurchases)")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Target Amount")
                        Spacer()
                        Text(plan.amountPerPurchase, format: .currency(code: "USD"))
                            .fontWeight(.medium)
                    }
                }

                Section("Transaction Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Shares")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("Shares", text: $sharesText)
                                        .textFieldStyle(.roundedBorder)

                                    if currentPrice != nil && suggestedShares > 0 {
                                        Button("Use \(suggestedShares, specifier: "%.4f")") {
                                            sharesText = String(format: "%.4f", suggestedShares)
                                            totalCostText = String(format: "%.2f", plan.amountPerPurchase)
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.caption)
                                        .help("Suggested shares for target amount")
                                    }
                                }
                            }
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Total Cost")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    TextField("Total Cost", text: $totalCostText)
                                        .textFieldStyle(.roundedBorder)
                                    Text("USD")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                            }

                            Button(action: fetchCurrentPrice) {
                                if isLoadingPrice {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(asset.type == .cd || asset.type == .cash || isLoadingPrice)
                            .help("Fetch current price")
                        }

                        // Show calculated average price
                        if shares > 0 && totalCost > 0 {
                            HStack {
                                Image(systemName: "function")
                                    .foregroundColor(.accentColor)
                                Text("Average Price: \(pricePerShare, format: .currency(code: "USD"))")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                if let price = currentPrice {
                                    let diff = ((pricePerShare - price) / price) * 100
                                    Text("(\(diff >= 0 ? "+" : "")\(diff, specifier: "%.1f")% vs market)")
                                        .font(.caption)
                                        .foregroundColor(abs(diff) < 1 ? Theme.StatusColors.positive : Theme.StatusColors.warning)
                                }
                            }
                        }
                    }
                }

                Section("Summary") {
                    HStack {
                        Text("Total Amount")
                        Spacer()
                        Text(totalCost, format: .currency(code: "USD"))
                            .fontWeight(.semibold)
                            .foregroundColor(totalCost > 0 ? .primary : .secondary)
                    }

                    if totalCost > 0 && plan.amountPerPurchase > 0 {
                        let difference = totalCost - plan.amountPerPurchase
                        let percentDiff = (difference / plan.amountPerPurchase) * 100
                        HStack {
                            Text("vs. Target")
                            Spacer()
                            Text("\(difference >= 0 ? "+" : "")\(difference, format: .currency(code: "USD")) (\(percentDiff, specifier: "%.1f")%)")
                                .font(.caption)
                                .foregroundColor(abs(percentDiff) < 5 ? Theme.StatusColors.positive : Theme.StatusColors.warning)
                        }
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Record Purchase") {
                    recordPurchase()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 450, height: 550)
        .onAppear {
            // Pre-fill with current price and target amount
            if let price = asset.currentPrice {
                currentPrice = price
            }
            totalCostText = String(format: "%.2f", plan.amountPerPurchase)
            notes = "DCA Plan Purchase #\(plan.completedPurchases + 1)"
            // Fetch latest price on appear
            fetchCurrentPrice()
        }
    }

    private func fetchCurrentPrice() {
        guard asset.type != .cd && asset.type != .cash else { return }

        isLoadingPrice = true

        Task {
            do {
                let quote = try await YahooFinanceService.shared.fetchQuote(symbol: asset.symbol)
                currentPrice = quote.price
                // Pre-calculate shares if totalCost is already set
                if totalCost > 0 && shares == 0 {
                    let suggestedShares = totalCost / quote.price
                    sharesText = String(format: "%.4f", suggestedShares)
                }
            } catch {
                // Ignore error, user can enter manually
            }
            isLoadingPrice = false
        }
    }

    private func recordPurchase() {
        viewModel.addTransaction(
            asset: asset,
            type: .buy,
            date: date,
            shares: shares,
            pricePerShare: pricePerShare,
            notes: notes.isEmpty ? nil : notes,
            linkedPlanId: plan.id
        )

        dismiss()
    }
}

// MARK: - Edit Plan Sheet

struct EditPlanSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    let plan: InvestmentPlan
    let asset: Asset

    @State private var totalAmountText: String
    @State private var numberOfPurchasesText: String
    @State private var frequency: PlanFrequency
    @State private var customDaysText: String
    @State private var startDate: Date
    @State private var notes: String

    var totalAmount: Double {
        Double(totalAmountText) ?? 0
    }

    var numberOfPurchases: Int {
        Int(numberOfPurchasesText) ?? 1
    }

    var amountPerPurchase: Double {
        guard numberOfPurchases > 0 else { return 0 }
        return totalAmount / Double(numberOfPurchases)
    }

    var isValid: Bool {
        totalAmount > 0 && numberOfPurchases > plan.completedPurchases
    }

    init(plan: InvestmentPlan, asset: Asset) {
        self.plan = plan
        self.asset = asset
        _totalAmountText = State(initialValue: String(format: "%.2f", plan.totalAmount))
        _numberOfPurchasesText = State(initialValue: String(plan.numberOfPurchases))
        _frequency = State(initialValue: plan.frequency)
        _customDaysText = State(initialValue: String(plan.customDaysBetween ?? 30))
        _startDate = State(initialValue: plan.startDate)
        _notes = State(initialValue: plan.notes ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Edit Investment Plan")
                        .font(.headline)
                    Text(asset.symbol)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Progress (Read-only)") {
                    HStack {
                        Text("Completed Purchases")
                        Spacer()
                        Text("\(plan.completedPurchases) of \(plan.numberOfPurchases)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Status")
                            .lineLimit(1)
                        Spacer()
                        HStack {
                            Image(systemName: plan.status.iconName)
                            Text(plan.status.displayName)
                        }
                        .foregroundColor(.secondary)
                    }
                }

                Section("Investment Details") {
                    HStack {
                        TextField("Total Amount to Invest", text: $totalAmountText)
                            .textFieldStyle(.roundedBorder)
                        Text("USD")
                            .foregroundColor(.secondary)
                    }

                    Stepper("Number of Purchases: \(numberOfPurchases)", value: Binding(
                        get: { numberOfPurchases },
                        set: { numberOfPurchasesText = String($0) }
                    ), in: max(1, plan.completedPurchases)...52)

                    if numberOfPurchases <= plan.completedPurchases {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.StatusColors.warning)
                            Text("Cannot be less than completed purchases (\(plan.completedPurchases))")
                                .font(.caption)
                                .foregroundColor(Theme.StatusColors.warning)
                        }
                    }

                    Picker("Frequency", selection: $frequency) {
                        ForEach(PlanFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)

                    if frequency == .custom {
                        HStack {
                            TextField("Days between purchases", text: $customDaysText)
                                .textFieldStyle(.roundedBorder)
                            Text("days")
                                .foregroundColor(.secondary)
                        }
                    }

                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }

                // Preview
                if isValid {
                    Section("Plan Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Amount per purchase:")
                                Spacer()
                                Text(amountPerPurchase, format: .currency(code: "USD"))
                                    .fontWeight(.semibold)
                            }

                            if amountPerPurchase != plan.amountPerPurchase {
                                HStack {
                                    Text("Original:")
                                    Spacer()
                                    Text(plan.amountPerPurchase, format: .currency(code: "USD"))
                                        .foregroundColor(.secondary)
                                }
                            }

                            HStack {
                                Text("Remaining purchases:")
                                Spacer()
                                Text("\(numberOfPurchases - plan.completedPurchases)")
                            }

                            let endDate = Calendar.current.date(
                                byAdding: .day,
                                value: (frequency == .custom ? (Int(customDaysText) ?? 30) : frequency.daysBetween) * (numberOfPurchases - plan.completedPurchases - 1),
                                to: Date()
                            )
                            if let end = endDate {
                                HStack {
                                    Text("Estimated completion:")
                                    Spacer()
                                    Text(end, style: .date)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes about this plan...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Save Changes") {
                    savePlan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func savePlan() {
        var updatedPlan = plan
        updatedPlan.totalAmount = totalAmount
        updatedPlan.numberOfPurchases = numberOfPurchases
        updatedPlan.amountPerPurchase = amountPerPurchase
        updatedPlan.frequency = frequency
        updatedPlan.customDaysBetween = frequency == .custom ? Int(customDaysText) : nil
        updatedPlan.startDate = startDate
        updatedPlan.notes = notes.isEmpty ? nil : notes

        viewModel.updatePlan(updatedPlan)
        dismiss()
    }
}

// MARK: - Add Plan Sheet

struct AddPlanSheet: View {
    @EnvironmentObject var viewModel: PortfolioViewModel
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    @State private var selectedAsset: Asset?
    @State private var totalAmountText = ""
    @State private var numberOfPurchasesText = "3"
    @State private var frequency: PlanFrequency = .monthly
    @State private var customDaysText = "30"
    @State private var startDate = Date()
    @State private var notes = ""

    @State private var isRequestingAISuggestion = false
    @State private var aiSuggestion: String?

    var totalAmount: Double {
        Double(totalAmountText) ?? 0
    }

    var numberOfPurchases: Int {
        Int(numberOfPurchasesText) ?? 1
    }

    var amountPerPurchase: Double {
        guard numberOfPurchases > 0 else { return 0 }
        return totalAmount / Double(numberOfPurchases)
    }

    var isValid: Bool {
        selectedAsset != nil && totalAmount > 0 && numberOfPurchases > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Create Investment Plan")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Form
            Form {
                Section("Asset") {
                    Picker("Select Asset", selection: $selectedAsset) {
                        Text("Choose an asset...").tag(nil as Asset?)
                        ForEach(databaseService.assets.filter { $0.type != .cd }) { asset in
                            HStack {
                                Text(asset.symbol)
                                Text("- \(asset.name)")
                                    .foregroundColor(.secondary)
                            }
                            .tag(asset as Asset?)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Investment Details") {
                    HStack {
                        TextField("Total Amount to Invest", text: $totalAmountText)
                            .textFieldStyle(.roundedBorder)
                        Text("USD")
                            .foregroundColor(.secondary)
                    }

                    Stepper("Number of Purchases: \(numberOfPurchases)", value: Binding(
                        get: { numberOfPurchases },
                        set: { numberOfPurchasesText = String($0) }
                    ), in: 1...52)

                    Picker("Frequency", selection: $frequency) {
                        ForEach(PlanFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    .pickerStyle(.menu)

                    if frequency == .custom {
                        HStack {
                            TextField("Days between purchases", text: $customDaysText)
                                .textFieldStyle(.roundedBorder)
                            Text("days")
                                .foregroundColor(.secondary)
                        }
                    }

                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }

                // Preview
                if isValid {
                    Section("Plan Preview") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Amount per purchase:")
                                Spacer()
                                Text(amountPerPurchase, format: .currency(code: "USD"))
                                    .fontWeight(.semibold)
                            }

                            HStack {
                                Text("Schedule:")
                                Spacer()
                                Text("\(numberOfPurchases) purchases, \(frequency.displayName.lowercased())")
                            }

                            let endDate = Calendar.current.date(
                                byAdding: .day,
                                value: (frequency == .custom ? (Int(customDaysText) ?? 30) : frequency.daysBetween) * (numberOfPurchases - 1),
                                to: startDate
                            )
                            if let end = endDate {
                                HStack {
                                    Text("Estimated completion:")
                                    Spacer()
                                    Text(end, style: .date)
                                }
                            }
                        }
                        .font(.subheadline)
                    }
                }

                Section("Notes (Optional)") {
                    TextField("Add notes about this plan...", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // AI Suggestion
                if OpenAIService.shared.isConfigured && selectedAsset != nil && totalAmount > 0 {
                    Section("AI Suggestion") {
                        if isRequestingAISuggestion {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Getting AI suggestion...")
                                    .foregroundColor(.secondary)
                            }
                        } else if let suggestion = aiSuggestion {
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Button("Get AI Investment Suggestion") {
                                getAISuggestion()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Create Plan") {
                    createPlan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }

    private func getAISuggestion() {
        guard let asset = selectedAsset else { return }

        isRequestingAISuggestion = true

        Task {
            do {
                let suggestion = try await OpenAIService.shared.suggestInvestmentPlan(
                    asset: asset,
                    amount: totalAmount
                )
                aiSuggestion = suggestion
            } catch {
                aiSuggestion = "Unable to get AI suggestion: \(error.localizedDescription)"
            }
            isRequestingAISuggestion = false
        }
    }

    private func createPlan() {
        guard let asset = selectedAsset else { return }

        viewModel.addInvestmentPlan(
            asset: asset,
            totalAmount: totalAmount,
            numberOfPurchases: numberOfPurchases,
            frequency: frequency,
            customDays: frequency == .custom ? Int(customDaysText) : nil,
            startDate: startDate,
            notes: notes.isEmpty ? nil : notes
        )

        dismiss()
    }
}

// MARK: - Plan Detail Sheet

struct PlanDetailSheet: View {
    let plan: InvestmentPlan
    @EnvironmentObject var databaseService: DatabaseService
    @Environment(\.dismiss) var dismiss

    var asset: Asset? {
        databaseService.getAsset(byId: plan.assetId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(asset?.symbol ?? "Unknown")
                        .font(.headline)
                    Text("Investment Plan Details")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Overview
                    GroupBox("Overview") {
                        VStack(spacing: 12) {
                            DetailRow(label: "Total Investment", value: plan.totalAmount.formatted(.currency(code: "USD")))
                            DetailRow(label: "Per Purchase", value: plan.amountPerPurchase.formatted(.currency(code: "USD")))
                            DetailRow(label: "Frequency", value: plan.frequency.displayName)
                            DetailRow(label: "Status", value: plan.status.displayName)
                        }
                    }

                    // Progress
                    GroupBox("Progress") {
                        VStack(alignment: .leading, spacing: 12) {
                            ProgressView(value: plan.progressPercent, total: 100)
                                .tint(plan.isOverdue ? Theme.StatusColors.warning : Theme.StatusColors.active)

                            DetailRow(label: "Completed", value: "\(plan.completedPurchases) of \(plan.numberOfPurchases)")
                            DetailRow(label: "Invested", value: plan.investedAmount.formatted(.currency(code: "USD")))
                            DetailRow(label: "Remaining", value: plan.remainingAmount.formatted(.currency(code: "USD")))
                        }
                    }

                    // Schedule
                    GroupBox("Purchase Schedule") {
                        VStack(spacing: 8) {
                            ForEach(plan.schedule) { item in
                                HStack {
                                    Text("#\(item.purchaseNumber)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 30)

                                    Text(item.scheduledDate, style: .date)

                                    Spacer()

                                    Text(item.amount, format: .currency(code: "USD"))

                                    if item.isCompleted {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    } else if item.isOverdue {
                                        Image(systemName: "exclamationmark.circle.fill")
                                            .foregroundColor(.orange)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                    }

                    // Notes
                    if let notes = plan.notes, !notes.isEmpty {
                        GroupBox("Notes") {
                            Text(notes)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 450, height: 550)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

#Preview {
    PlansView()
        .environmentObject(DatabaseService.shared)
        .environmentObject(PortfolioViewModel())
}
