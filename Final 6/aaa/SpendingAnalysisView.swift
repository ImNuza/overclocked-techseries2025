import SwiftUI
import Charts

struct SpendingAnalysisView: View {
    @EnvironmentObject var store: ReceiptStore
    @State private var selectedTimeframe: Timeframe = .month

    enum Timeframe: String, CaseIterable, Identifiable {
        case week = "This Week"
        case month = "This Month"
        case year = "This Year"
        case all = "All Time"
        var id: String { self.rawValue }
    }

    // MARK: - Filtered data
    private var filteredReceipts: [Receipt] {
        let now = Date()
        let cal = Calendar.current
        let startDate: Date = {
            switch selectedTimeframe {
            case .week:
                return cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            case .month:
                return cal.date(from: cal.dateComponents([.year, .month], from: now))!
            case .year:
                return cal.date(from: cal.dateComponents([.year], from: now))!
            case .all:
                return .distantPast
            }
        }()
        return store.receipts.filter { $0.date >= startDate }
    }

    // MARK: - Summary metrics
    private var totalSpending: Decimal { filteredReceipts.reduce(0) { $0 + $1.amount } }
    private var transactionCount: Int { filteredReceipts.count }
    private var avgPerTxn: Decimal { transactionCount > 0 ? totalSpending / Decimal(transactionCount) : 0 }

    // MARK: - Category & Merchant
    private var categorySpending: [CategorySpending] {
        let grouped = Dictionary(grouping: filteredReceipts, by: { $0.category })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.map { CategorySpending(category: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }
    private var merchantSpending: [MerchantSpending] {
        let grouped = Dictionary(grouping: filteredReceipts, by: { $0.merchant })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        return grouped.map { MerchantSpending(merchant: $0.key, amount: $0.value) }
            .sorted { $0.amount > $1.amount }
    }

    // MARK: - Trend Data
    private var trendData: [SpendingTrendData] {
        let cal = Calendar.current
        let now = Date()
        switch selectedTimeframe {
        case .week:
            let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            return (0..<7).map { i in
                let day = cal.startOfDay(for: cal.date(byAdding: .day, value: i, to: startOfWeek)!)
                let sum = filteredReceipts.filter { cal.isDate($0.date, inSameDayAs: day) }.reduce(0) { $0 + $1.amount }
                return SpendingTrendData(date: day, amount: sum)
            }
        case .month:
            let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let nextMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!
            var weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: startOfMonth))!
            var points: [SpendingTrendData] = []
            while weekStart < nextMonth {
                let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
                let sum = filteredReceipts.filter { $0.date >= weekStart && $0.date < weekEnd }.reduce(0) { $0 + $1.amount }
                points.append(SpendingTrendData(date: weekStart, amount: sum))
                weekStart = weekEnd
            }
            return points.sorted()
        case .year:
            let startOfYear = cal.date(from: cal.dateComponents([.year], from: now))!
            return (0..<12).map { m in
                let mStart = cal.date(byAdding: .month, value: m, to: startOfYear)!
                let mEnd = cal.date(byAdding: .month, value: 1, to: mStart)!
                let sum = filteredReceipts.filter { $0.date >= mStart && $0.date < mEnd }.reduce(0) { $0 + $1.amount }
                return SpendingTrendData(date: mStart, amount: sum)
            }
        case .all:
            let grouped = Dictionary(grouping: filteredReceipts) { r in
                cal.date(from: cal.dateComponents([.year, .month], from: r.date))!
            }.mapValues { $0.reduce(0) { $0 + $1.amount } }
            return grouped.map { SpendingTrendData(date: $0.key, amount: $0.value) }.sorted()
        }
    }

    // MARK: - Month Numeric (1~4주)
    private var monthTrendNumeric: [MonthWeekPoint] {
        var buckets: [Int: Decimal] = [1: 0, 2: 0, 3: 0, 4: 0]
        for r in filteredReceipts {
            var w = weekIndexInMonth(for: r.date)
            w = min(4, max(1, w)) // 5주차 이상은 4주차 합산
            buckets[w, default: 0] += r.amount
        }
        return (1...4).map { MonthWeekPoint(week: $0, amount: buckets[$0] ?? 0) }
    }
    private struct MonthWeekPoint: Identifiable { let id = UUID(); let week: Int; let amount: Decimal }

    // MARK: - Chart Axis
    private var trendChartUnit: Calendar.Component {
        switch selectedTimeframe {
        case .week: return .day
        case .month: return .weekOfYear
        case .year, .all: return .month
        }
    }
    private var chartXAxisFormat: Date.FormatStyle {
        switch selectedTimeframe {
        case .week: return .dateTime.weekday(.narrow)
        case .month: return .dateTime.week(.defaultDigits)
        case .year: return .dateTime.month(.defaultDigits)
        case .all: return .dateTime.year().month(.abbreviated)
        }
    }
    private func weekIndexInMonth(for date: Date) -> Int {
        let cal = Calendar.current
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let monthStartWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: monthStart))!
        let dateWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
        return (cal.dateComponents([.weekOfYear], from: monthStartWeek, to: dateWeek).weekOfYear ?? 0) + 1
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    Text("Analysis").font(.largeTitle.bold()).padding(.bottom, -10)
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented)
                    if filteredReceipts.isEmpty { emptyDataView } else {
                        summaryMetrics
                        spendingTrendCard
                        categoryBreakdownCard
                        topMerchantsCard
                    }
                }.padding()
            }
        }
    }

    // MARK: - Cards
    private var summaryMetrics: some View {
        VStack(spacing: 16) {
            AnalysisMetricCard(icon: "dollarsign.circle.fill", title: "Total Spending", value: totalSpending.formatted(.currency(code: "SGD")), color: Color("ThemeGreen"))
            AnalysisMetricCard(icon: "number.circle.fill", title: "Transactions", value: "\(transactionCount)", color: .blue)
            AnalysisMetricCard(icon: "divide.circle.fill", title: "Avg / Transaction", value: avgPerTxn.formatted(.currency(code: "SGD")), color: .purple)
        }
    }

    private var spendingTrendCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Spending Trend").font(.title2.bold())

            // Month 전용: 1~4주차 Chart
            if selectedTimeframe == .month {
                Chart {
                    ForEach(monthTrendNumeric) { p in
                        BarMark(x: .value("Week", p.week), y: .value("Amount", p.amount))
                    }
                }
                .foregroundStyle(Color("ThemeGreen").gradient)
                .cornerRadius(6)
                .chartXAxis {
                    AxisMarks(values: [1, 2, 3, 4]) { v in
                        AxisGridLine()
                        if let w = v.as(Int.self) { AxisValueLabel("\(w)") }
                    }
                }
                .chartXScale(domain: 1...4)
                .frame(height: 200)
            } else {
                // Week/Year/All: 기존 Date 축
                Chart {
                    ForEach(trendData) { d in
                        BarMark(x: .value("Date", d.date, unit: trendChartUnit), y: .value("Amount", d.amount))
                    }
                }
                .foregroundStyle(Color("ThemeGreen").gradient)
                .cornerRadius(6)
                .chartXAxis {
                    AxisMarks(values: .stride(by: trendChartUnit)) {
                        AxisGridLine()
                        AxisValueLabel(format: chartXAxisFormat)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }

    private var categoryBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Categories").font(.title2.bold())
            Chart(categorySpending.prefix(5)) { s in
                SectorMark(angle: .value("Amount", s.amount), innerRadius: .ratio(0.65))
                    .foregroundStyle(by: .value("Category", s.category.rawValue))
            }
            .chartLegend(position: .bottom)
            .frame(height: 200)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }

    private var topMerchantsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Merchants").font(.title2.bold())
            ForEach(merchantSpending.prefix(5)) { s in
                HStack {
                    Text(s.merchant).font(.headline)
                    Spacer()
                    Text(s.amount.formatted(.currency(code: "SGD"))).foregroundColor(.secondary)
                }
                if s.id != merchantSpending.prefix(5).last?.id { Divider() }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }

    private var emptyDataView: some View {
        VStack(spacing: 15) {
            Image(systemName: "chart.bar.xaxis.ascending").font(.system(size: 60)).foregroundColor(.secondary.opacity(0.3))
            Text("No Spending Data").font(.title2.bold())
            Text("Receipts you add will be analyzed here for the selected period.")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 50)
        .background(Color(.secondarySystemBackground)).cornerRadius(20)
    }
}

// MARK: - Reusable
struct AnalysisMetricCard: View {
    let icon: String; let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundColor(.secondary)
            HStack(alignment: .bottom, spacing: 8) {
                Image(systemName: icon).font(.title.bold()).foregroundColor(color)
                Text(value).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
    }
}

struct CategorySpending: Identifiable, Hashable { let id = UUID(); let category: Category; let amount: Decimal }
struct MerchantSpending: Identifiable, Hashable { let id = UUID(); let merchant: String; let amount: Decimal }
struct SpendingTrendData: Identifiable, Comparable {
    let id = UUID(); let date: Date; let amount: Decimal
    static func < (lhs: SpendingTrendData, rhs: SpendingTrendData) -> Bool { lhs.date < rhs.date }
}
