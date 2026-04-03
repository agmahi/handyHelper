import SwiftUI
import MWDATCore

// MARK: - Design System (Rams-inspired palette)

private enum Rams {
    // Neutral base — warm off-whites and grays (Braun product language)
    static let background = Color(hex: "F5F3F0")
    static let surface = Color(hex: "FFFFFF")
    static let textPrimary = Color(hex: "1A1A1A")
    static let textSecondary = Color(hex: "8A8A8A")
    static let divider = Color(hex: "E8E5E0")

    // PO signal colors — bright, punchy, intentional
    static let active = Color(hex: "2D8C4E")       // Green: connected/success
    static let alert = Color(hex: "FF4F58")         // PO hot coral: errors/destructive
    static let accent = Color(hex: "FF6B2B")        // PO signature orange: primary actions
    static let highlight = Color(hex: "F2A900")     // Amber: reward rate callout

    // Typography
    static let monoFont = Font.system(.caption, design: .monospaced)
}

// MARK: - CardMaxView

struct CardMaxView: View {
    @ObservedObject var viewModel: CardMaxViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    @State private var expandedCardId: UUID?
    @State private var showAddCard = false
    @State private var selectedReceipt: Receipt?
    @State private var showCaptureOptions = false
    @State private var showPhoneCamera = false
    @State private var showPhotoLibrary = false
    @State private var cardToRemove: CreditCard?
    @State private var showDashboard = false

    var body: some View {
        ZStack {
            Rams.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    statusBar
                    stateView
                    receiptSection
                    cardWallet
                    #if DEBUG
                    debugPanel
                    #endif
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("CardMax")
        .navigationBarTitleDisplayMode(.large)
        .alert("Remove Card", isPresented: Binding(
            get: { cardToRemove != nil },
            set: { if !$0 { cardToRemove = nil } }
        )) {
            Button("Remove", role: .destructive) {
                if let card = cardToRemove {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expandedCardId = nil
                        viewModel.removeCard(card)
                    }
                }
                cardToRemove = nil
            }
            Button("Cancel", role: .cancel) {
                cardToRemove = nil
            }
        } message: {
            if let card = cardToRemove {
                Text("Remove \(card.fullName) from your wallet?")
            }
        }
        .sheet(item: $selectedReceipt) { receipt in
            if let index = viewModel.receipts.firstIndex(where: { $0.id == receipt.id }) {
                ReceiptDetailView(
                    receipt: $viewModel.receipts[index],
                    userCards: viewModel.userCards,
                    onDelete: {
                        viewModel.deleteReceipt(receipt)
                        selectedReceipt = nil
                    },
                    onUpdate: {
                        ReceiptStorageService.save(viewModel.receipts)
                    }
                )
            }
        }
        .onAppear {
            // Force dark nav title on light background
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Rams.textPrimary)]
            appearance.titleTextAttributes = [.foregroundColor: UIColor(Rams.textPrimary)]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 0) {
            // Connection indicator — contrasting pill
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isGlassesConnected ? Rams.active : Rams.alert)
                    .frame(width: 6, height: 6)
                Text(viewModel.isGlassesConnected ? "Connected" : "No Glasses")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(viewModel.isGlassesConnected ? Rams.active : Rams.alert)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(viewModel.isGlassesConnected
                          ? Rams.active.opacity(0.1)
                          : Rams.alert.opacity(0.1))
            )

            Spacer()
        }
    }

    // MARK: - State View

    @ViewBuilder
    private var stateView: some View {
        switch viewModel.state {
        case .idle:
            quickGlance
        case .detecting:
            activeStateCard {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Rams.textPrimary)
                    Text("Detecting...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Rams.textSecondary)
                }
            }
        case .recommending(let rec):
            activeStateCard {
                VStack(spacing: 20) {
                    Text("\(Int(rec.rewardRate))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(Rams.accent)
                    Text(rec.card.fullName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Rams.textPrimary)
                    Text(rec.reason)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Rams.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        case .capturing:
            activeStateCard {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(Rams.textPrimary)
                    Text("Capturing...")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundColor(Rams.textSecondary)
                }
            }
        case .error(let message):
            activeStateCard {
                VStack(spacing: 12) {
                    Circle()
                        .fill(Rams.alert.opacity(0.12))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(Rams.alert)
                        )
                    Text(message)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(Rams.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    /// Wrapper for detecting/recommending/error states
    private func activeStateCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .padding(.horizontal, 24)
            .background(Rams.surface)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }

    // MARK: - Quick Glance (top categories + best cards)

    /// Top 5 spending categories with the best card for each
    private var topCategoryCards: [(category: MerchantCategory, card: CreditCard, rate: Float)] {
        let topCategories: [MerchantCategory] = [.dining, .grocery, .gas, .travel, .online]
        return topCategories.compactMap { category in
            if let rec = viewModel.service.recommendForCategory(category) {
                return (category, rec.card, rec.rewardRate)
            }
            return nil
        }
    }

    private var quickGlance: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUICK GLANCE")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Rams.textSecondary)
                .padding(.bottom, 14)

            VStack(spacing: 0) {
                ForEach(Array(topCategoryCards.enumerated()), id: \.element.category.rawValue) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        // Category icon
                        Image(systemName: categoryIcon(item.category))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Rams.textSecondary)
                            .frame(width: 28)

                        // Category name
                        Text(item.category.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Rams.textPrimary)

                        Spacer()

                        // Best card + owner + rate
                        Text(item.card.owner == "Me" ? item.card.nickname : "\(item.card.owner)'s \(item.card.nickname)")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(Rams.textSecondary)

                        Text("\(Int(item.rate))%")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(item.rate >= 3.0 ? Rams.accent : Rams.textPrimary)
                            .frame(width: 32, alignment: .trailing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Rams.surface)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private func categoryIcon(_ category: MerchantCategory) -> String {
        switch category {
        case .dining: return "fork.knife"
        case .grocery: return "cart"
        case .gas: return "fuelpump"
        case .travel: return "airplane"
        case .online: return "bag"
        case .entertainment: return "ticket"
        case .drugstore: return "cross.case"
        case .streaming: return "play.tv"
        case .transportation: return "car"
        default: return "creditcard"
        }
    }

    // MARK: - Card Wallet (vertical stack, slide-out)

    private let cardExpandedWidth: CGFloat = 210
    private let cardHeight: CGFloat = 220
    private let cardOverlap: CGFloat = -8

    private var cardWallet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("YOUR CARDS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Rams.textSecondary)

                Spacer()

                Button {
                    showAddCard = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Rams.accent)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 12)

            GeometryReader { geo in
                let cardCount = viewModel.userCards.count
                let hasExpanded = expandedCardId != nil && viewModel.userCards.contains(where: { $0.id == expandedCardId })
                let collapsedCount = max(1, hasExpanded ? cardCount - 1 : cardCount)
                // Negative overlap reduces total width needed, so subtract it (adds space back)
                let overlapSavings = CGFloat(max(0, cardCount - 1)) * abs(cardOverlap)
                let expandedSpace = hasExpanded ? cardExpandedWidth : 0
                let spineWidth = max(36, (geo.size.width + overlapSavings - expandedSpace) / CGFloat(collapsedCount))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: cardOverlap) {
                        ForEach(Array(viewModel.userCards.enumerated()), id: \.element.id) { index, card in
                            let isExpanded = expandedCardId == card.id
                            let isRecommended = viewModel.lastRecommendation?.card.id == card.id

                            walletCard(card, isExpanded: isExpanded, isRecommended: isRecommended, spineWidth: spineWidth)
                                .zIndex(isExpanded ? 100 : Double(index))
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                        expandedCardId = isExpanded ? nil : card.id
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 4) // room for shadow
                }
            }
            .frame(height: cardHeight + 8) // fixed height for GeometryReader
        }
        .sheet(isPresented: $showAddCard) {
            AddCardView(viewModel: viewModel)
        }
    }

    private func walletCard(_ card: CreditCard, isExpanded: Bool, isRecommended: Bool, spineWidth: CGFloat) -> some View {
        let cardColor = Color(hex: card.color.hexValue)
        let width = isExpanded ? cardExpandedWidth : spineWidth

        return ZStack(alignment: .leading) {
            if isExpanded {
                // Expanded face — reward details
                expandedCardFace(card)
            } else {
                // Collapsed spine — rotated name
                cardSpineLabel(card)
            }
        }
        .frame(width: width, height: cardHeight)
        .cardMaterial(color: cardColor, cornerRadius: 12)
        .overlay(
            isRecommended
                ? RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Rams.accent, lineWidth: 2.5)
                : nil
        )
        .shadow(
            color: .black.opacity(isExpanded ? 0.25 : 0.1),
            radius: isExpanded ? 12 : 4,
            x: isExpanded ? 0 : 2,
            y: isExpanded ? 6 : 3
        )
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
    }

    private func cardSpineLabel(_ card: CreditCard) -> some View {
        VStack(spacing: 6) {
            Text(card.nickname)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.9))
                .rotationEffect(.degrees(-90))
                .fixedSize()

            if card.owner != "Me" {
                Text(card.owner.prefix(1))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(.white.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func expandedCardFace(_ card: CreditCard) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 3) {
                Text(card.fullName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    Text(card.issuer.displayName)
                    if card.owner != "Me" {
                        Text("·")
                        Text(card.owner)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)
                .padding(.horizontal, 10)

            // Rewards — scrollable if many
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(card.merchantBonuses.sorted(by: { $0.value > $1.value }), id: \.key) { merchantId, rate in
                        expandedRewardRow(
                            label: merchantDisplayName(merchantId),
                            rate: rate,
                            isHighlight: true
                        )
                    }

                    let effective = card.effectiveCategoryRewards
                    let rotatingCats = Set(card.activeRotatingCategories?.categories ?? [])

                    ForEach(effective.sorted(by: { $0.value > $1.value }), id: \.key.rawValue) { category, rate in
                        expandedRewardRow(
                            label: category.displayName + (rotatingCats.contains(category) ? " Q\(currentQuarter)" : ""),
                            rate: rate,
                            isHighlight: rate >= 3.0
                        )
                    }

                    expandedRewardRow(
                        label: "Everything else",
                        rate: card.defaultRate,
                        isHighlight: false
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            Spacer(minLength: 0)

            // Color swatches
            HStack(spacing: 6) {
                ForEach(CardColor.allCases, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color.hexValue))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: card.color == color ? 2 : 0)
                        )
                        .onTapGesture {
                            viewModel.updateCardColor(card, to: color)
                        }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)

            // Remove — triggers confirmation alert
            Button {
                cardToRemove = card
            } label: {
                Text("Remove")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Rams.alert)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Rams.alert.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
    }

    private func expandedRewardRow(label: String, rate: Float, isHighlight: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.7))
                .lineLimit(1)

            Spacer()

            Text("\(Int(rate))%")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(isHighlight ? Color(hex: "FF6B2B") : .white.opacity(0.5))
        }
        .padding(.vertical, 3)
    }

    private var currentQuarter: Int {
        let month = Calendar.current.component(.month, from: Date())
        return ((month - 1) / 3) + 1
    }

    private func merchantDisplayName(_ id: String) -> String {
        if let merchant = Merchant.presetMerchants.first(where: { $0.id == id }) {
            return merchant.displayName
        }
        return id.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // MARK: - Receipts

    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECEIPTS")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(Rams.textSecondary)

                Spacer()

                if !viewModel.receipts.isEmpty {
                    Button {
                        showDashboard = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Patterns")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Rams.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Rams.accent.opacity(0.12))
                        .cornerRadius(14)
                    }
                }

                Button {
                    showCaptureOptions = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                        Text("Add")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Rams.accent)
                    .cornerRadius(14)
                }
                .disabled(viewModel.state == .capturing)
            }
            .padding(.bottom, 10)

            if viewModel.receipts.isEmpty {
                Text("Capture receipts to track purchases.")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(Rams.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .background(Rams.surface)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.receipts) { receipt in
                            receiptThumbnail(receipt)
                        }
                    }
                }
            }
        }
        .confirmationDialog("Add Receipt", isPresented: $showCaptureOptions) {
            if viewModel.isGlassesConnected {
                Button("Capture with Glasses") {
                    Task { await viewModel.captureReceipt() }
                }
            }
            Button("Take Photo") {
                showPhoneCamera = true
            }
            Button("Choose from Library") {
                showPhotoLibrary = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $showPhoneCamera) {
            ImagePicker(source: .camera) { image in
                viewModel.saveReceipt(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showPhotoLibrary) {
            ImagePicker(source: .photoLibrary) { image in
                viewModel.saveReceipt(image: image)
            }
        }
        .sheet(isPresented: $showDashboard) {
            SpendingDashboardView(receipts: viewModel.receipts, userCards: viewModel.userCards)
        }
    }

    private func receiptThumbnail(_ receipt: Receipt) -> some View {
        Button {
            selectedReceipt = receipt
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .bottomLeading) {
                    if let image = receipt.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 100)
                            .cornerRadius(10)
                            .clipped()
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Rams.divider)
                            .frame(width: 80, height: 100)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(Rams.textSecondary)
                            )
                    }

                    // Annotation badge
                    if receipt.hasAnnotation {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Rams.accent.opacity(0.9))
                            .cornerRadius(6)
                            .padding(4)
                    }
                }

                if let merchant = receipt.merchantName {
                    Text(merchant)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Rams.textPrimary)
                        .lineLimit(1)
                        .frame(width: 80)
                } else {
                    Text(receipt.capturedAt, style: .date)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundColor(Rams.textSecondary)
                }
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                viewModel.deleteReceipt(receipt)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Debug Panel

    #if DEBUG
    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DEBUG")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Rams.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 8) {
                ForEach(Merchant.presetMerchants.prefix(6), id: \.id) { merchant in
                    Button {
                        viewModel.simulateDetection(merchant: merchant)
                    } label: {
                        Text(merchant.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Rams.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(Rams.divider)
                            .cornerRadius(8)
                    }
                }
            }

            // Category quick-test
            HStack(spacing: 8) {
                ForEach([MerchantCategory.dining, .grocery, .gas], id: \.self) { category in
                    Button {
                        viewModel.simulateCategoryRecommendation(category)
                    } label: {
                        Text(category.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Rams.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Rams.divider)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(16)
        .background(Rams.surface)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
    #endif
}

// MARK: - Card Material Modifier

/// Gives a view the look of a physical card: matte fill, top-edge highlight,
/// subtle noise texture, and a bottom-edge shadow line for thickness.
struct CardMaterialModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base fill
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(color)

                    // Top edge highlight — simulates light catching the edge
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear, .clear, .black.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    // Subtle inner border for edge definition
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.2), .clear, .black.opacity(0.15)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func cardMaterial(color: Color, cornerRadius: CGFloat = 10) -> some View {
        modifier(CardMaterialModifier(color: color, cornerRadius: cornerRadius))
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF) / 255
        g = Double((int >> 8) & 0xFF) / 255
        b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
