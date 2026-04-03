import SwiftUI

// MARK: - Spending Dashboard

struct SpendingDashboardView: View {
    let receipts: [Receipt]
    let userCards: [CreditCard]

    @Environment(\.dismiss) private var dismiss

    private let textPrimary = Color(hex: "1A1A1A")
    private let textSecondary = Color(hex: "6A6A6A")
    private let surface = Color.white
    private let bg = Color(hex: "F5F3F0")

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    summaryHeader
                    if !categoryData.isEmpty {
                        donutChart
                    }
                    categoryBreakdown
                    merchantFrequency
                    cardUsage
                }
                .padding(20)
            }
            .background(bg.ignoresSafeArea())
            .navigationTitle("Spending Patterns")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(textPrimary)
                }
            }
        }
    }

    // MARK: - Data

    private var annotatedReceipts: [Receipt] {
        receipts.filter { $0.hasAnnotation }
    }

    private var categoryData: [(category: MerchantCategory, count: Int)] {
        var counts: [MerchantCategory: Int] = [:]
        for receipt in annotatedReceipts {
            if let cat = receipt.category {
                counts[cat, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
            .map { (category: $0.key, count: $0.value) }
    }

    private var merchantData: [(name: String, count: Int, category: MerchantCategory?)] {
        var counts: [String: (count: Int, category: MerchantCategory?)] = [:]
        for receipt in annotatedReceipts {
            if let name = receipt.merchantName {
                let existing = counts[name]
                counts[name] = (count: (existing?.count ?? 0) + 1, category: receipt.category)
            }
        }
        return counts.map { (name: $0.key, count: $0.value.count, category: $0.value.category) }
            .sorted { $0.count > $1.count }
    }

    private var cardData: [(card: String, count: Int)] {
        var counts: [String: Int] = [:]
        for receipt in annotatedReceipts {
            if let card = receipt.recommendedCard {
                counts[card, default: 0] += 1
            }
        }
        return counts.sorted { $0.value > $1.value }
            .map { (card: $0.key, count: $0.value) }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: 12) {
            statPill(value: "\(receipts.count)", label: "Receipts")
            statPill(value: "\(annotatedReceipts.count)", label: "Identified")
            statPill(value: "\(categoryData.count)", label: "Categories")
        }
    }

    private func statPill(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(textPrimary)
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Donut Chart

    private var totalCategoryCount: Int {
        categoryData.reduce(0) { $0 + $1.count }
    }

    private var donutChart: some View {
        VStack(spacing: 16) {
            ZStack {
                // Donut segments
                ForEach(Array(donutSegments.enumerated()), id: \.offset) { _, segment in
                    Circle()
                        .trim(from: segment.start, to: segment.end)
                        .stroke(segment.color, style: StrokeStyle(lineWidth: 28, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                }

                // Center label
                VStack(spacing: 2) {
                    Text("\(totalCategoryCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(textPrimary)
                    Text("purchases")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(textSecondary)
                }
            }
            .frame(width: 160, height: 160)
            .padding(.top, 8)

            // Legend
            let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(categoryData, id: \.category.rawValue) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(categoryColor(item.category))
                            .frame(width: 8, height: 8)
                        Text(item.category.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textPrimary)
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(textSecondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(20)
        .background(surface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private struct DonutSegment {
        let start: CGFloat
        let end: CGFloat
        let color: Color
    }

    private var donutSegments: [DonutSegment] {
        let total = CGFloat(totalCategoryCount)
        guard total > 0 else { return [] }
        var segments: [DonutSegment] = []
        var current: CGFloat = 0
        let gap: CGFloat = 0.005 // small gap between segments

        for item in categoryData {
            let slice = CGFloat(item.count) / total
            let start = current + gap
            let end = current + slice - gap
            if end > start {
                segments.append(DonutSegment(
                    start: start,
                    end: end,
                    color: categoryColor(item.category)
                ))
            }
            current += slice
        }
        return segments
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORIES")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(textSecondary)

            if categoryData.isEmpty {
                emptyState("Capture receipts to see category patterns.")
            } else {
                let maxCount = categoryData.first?.count ?? 1

                VStack(spacing: 0) {
                    ForEach(Array(categoryData.enumerated()), id: \.element.category.rawValue) { index, item in
                        if index > 0 {
                            Divider().padding(.horizontal, 16)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(categoryColor(item.category))
                                .frame(width: 24)

                            Text(item.category.displayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textPrimary)

                            Spacer()

                            GeometryReader { geo in
                                let barWidth = geo.size.width * CGFloat(item.count) / CGFloat(maxCount)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(categoryColor(item.category))
                                    .frame(width: max(barWidth, 4), height: 8)
                                    .frame(maxHeight: .infinity, alignment: .center)
                            }
                            .frame(width: 60)

                            Text("\(item.count)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(textPrimary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(surface)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }

    // MARK: - Merchant Frequency

    private var merchantFrequency: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TOP MERCHANTS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(textSecondary)

            if merchantData.isEmpty {
                emptyState("No merchants identified yet.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(merchantData.prefix(8).enumerated()), id: \.element.name) { index, item in
                        if index > 0 {
                            Divider().padding(.horizontal, 16)
                        }

                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(textSecondary)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(textPrimary)
                                    .lineLimit(1)

                                if let cat = item.category {
                                    Text(cat.displayName)
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundColor(textSecondary)
                                }
                            }

                            Spacer()

                            Text("\(item.count)x")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(hex: "FF6B2B"))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .background(surface)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }

    // MARK: - Card Usage

    private var cardUsage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOMMENDED CARDS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(textSecondary)

            if cardData.isEmpty {
                emptyState("Card recommendations will appear as you capture receipts.")
            } else {
                let total = cardData.reduce(0) { $0 + $1.count }

                VStack(spacing: 0) {
                    ForEach(Array(cardData.enumerated()), id: \.element.card) { index, item in
                        if index > 0 {
                            Divider().padding(.horizontal, 16)
                        }

                        HStack(spacing: 12) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(textSecondary)
                                .frame(width: 24)

                            Text(item.card)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(textPrimary)

                            Spacer()

                            let pct = total > 0 ? Int(round(Double(item.count) / Double(total) * 100)) : 0
                            Text("\(pct)%")
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundColor(textSecondary)

                            Text("\(item.count)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(textPrimary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                .background(surface)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
        }
    }

    // MARK: - Helpers

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundColor(textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .background(surface)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    private func categoryColor(_ category: MerchantCategory) -> Color {
        switch category {
        case .dining: return Color(hex: "B5453A")
        case .grocery: return Color(hex: "5A7247")
        case .gas: return Color(hex: "C8893E")
        case .travel: return Color(hex: "3D7A8A")
        case .online: return Color(hex: "8A5A6A")
        case .entertainment: return Color(hex: "FF6B2B")
        case .drugstore: return Color(hex: "6B8E9B")
        case .streaming: return Color(hex: "9B6B8E")
        case .transportation: return Color(hex: "7A6B3D")
        default: return Color(hex: "8A8A8A")
        }
    }
}
