import AppIntents

// MARK: - Merchant or Category enum for Siri parameter

enum CardQuery: String, AppEnum {
    // Categories
    case dining, grocery, gas, travel, online, entertainment, drugstore, streaming, transportation

    // Top merchants
    case amazon, walmart, target, starbucks, mcdonalds, costco, wholefoods
    case shell, exxon, homedepot, cvs, walgreens, kroger, uber, lyft

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Place or Category")

    static var caseDisplayRepresentations: [CardQuery: DisplayRepresentation] = [
        .dining: "Dining", .grocery: "Groceries", .gas: "Gas", .travel: "Travel",
        .online: "Online Shopping", .entertainment: "Entertainment", .drugstore: "Drugstore",
        .streaming: "Streaming", .transportation: "Transportation",
        .amazon: "Amazon", .walmart: "Walmart", .target: "Target",
        .starbucks: "Starbucks", .mcdonalds: "McDonald's", .costco: "Costco",
        .wholefoods: "Whole Foods", .shell: "Shell", .exxon: "Exxon",
        .homedepot: "Home Depot", .cvs: "CVS", .walgreens: "Walgreens",
        .kroger: "Kroger", .uber: "Uber", .lyft: "Lyft",
    ]

    /// Returns a merchant if this query maps to one, nil if it's a category
    var merchant: Merchant? {
        let merchantIds: [CardQuery: String] = [
            .amazon: "amazon", .walmart: "walmart", .target: "target",
            .starbucks: "starbucks", .mcdonalds: "mcdonalds", .costco: "costco",
            .wholefoods: "whole_foods", .shell: "shell", .exxon: "exxon",
            .homedepot: "home_depot", .cvs: "cvs", .walgreens: "walgreens",
            .kroger: "kroger", .uber: "uber", .lyft: "lyft",
        ]
        guard let id = merchantIds[self] else { return nil }
        return Merchant.presetMerchants.first { $0.id == id }
    }

    /// Returns a category if this query maps to one
    var category: MerchantCategory? {
        let categories: [CardQuery: MerchantCategory] = [
            .dining: .dining, .grocery: .grocery, .gas: .gas, .travel: .travel,
            .online: .online, .entertainment: .entertainment, .drugstore: .drugstore,
            .streaming: .streaming, .transportation: .transportation,
        ]
        return categories[self]
    }
}

// MARK: - "Which Card?" Siri Intent

struct WhichCardIntent: AppIntent {
    static var title: LocalizedStringResource = "Which Card?"
    static var description = IntentDescription("Get the best credit card for a merchant or purchase category")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Place or Category")
    var query: CardQuery?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let service = CardMaxService.shared

        if let query {
            // Merchant match
            if let merchant = query.merchant {
                if let rec = service.recommendationEngine.recommend(for: merchant, from: service.userCards) {
                    return .result(dialog: "\(rec.spokenResponse)")
                }
            }

            // Category match
            if let category = query.category {
                if let rec = service.recommendForCategory(category) {
                    return .result(dialog: "\(rec.spokenResponse)")
                }
            }

            return .result(dialog: "No card data for that. Try dining, grocery, or gas.")
        }

        // No query — try camera
        if let rec = await service.detectAndRecommend() {
            return .result(dialog: "\(rec.spokenResponse)")
        }

        return .result(dialog: "Tell me where you're shopping. Say which card at Costco, or which card for gas.")
    }
}

// MARK: - App Shortcuts Provider

struct CardMaxShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WhichCardIntent(),
            phrases: [
                "Which card \(.applicationName)",
                "Which card at \(\.$query) \(.applicationName)",
                "Which card for \(\.$query) \(.applicationName)",
                "Best card for \(\.$query) \(.applicationName)",
                "What card at \(\.$query) \(.applicationName)",
                "What card for \(\.$query) \(.applicationName)",
            ],
            shortTitle: "Which Card?",
            systemImageName: "creditcard.fill"
        )
    }
}
