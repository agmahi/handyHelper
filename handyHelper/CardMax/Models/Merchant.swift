import Foundation
import CoreLocation

// MARK: - Merchant Model

struct Merchant: Identifiable, Codable, Hashable {
    let id: String                          // Unique identifier
    let name: String                        // Internal name
    let displayName: String                 // User-friendly name
    let primaryCategory: MerchantCategory   // Main category
    let subCategories: [MerchantCategory]   // Additional categories
    let logoName: String?                   // Asset name for logo
    let domains: [String]                   // Website domains
    let aliases: [String]                   // Alternative names/spellings
    let commonKeywords: [String]            // Keywords for text detection

    init(
        id: String,
        name: String,
        displayName: String,
        primaryCategory: MerchantCategory,
        subCategories: [MerchantCategory] = [],
        logoName: String? = nil,
        domains: [String] = [],
        aliases: [String] = [],
        commonKeywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.displayName = displayName
        self.primaryCategory = primaryCategory
        self.subCategories = subCategories
        self.logoName = logoName
        self.domains = domains
        self.aliases = aliases
        self.commonKeywords = commonKeywords
    }
}

// MARK: - Merchant Category

enum MerchantCategory: String, CaseIterable, Codable {
    case dining = "dining"
    case grocery = "grocery"
    case gas = "gas"
    case travel = "travel"
    case online = "online"
    case entertainment = "entertainment"
    case drugstore = "drugstore"
    case home_improvement = "home_improvement"
    case wholesale = "wholesale"
    case streaming = "streaming"
    case transportation = "transportation"
    case other = "other"

    var displayName: String {
        switch self {
        case .dining: return "Dining"
        case .grocery: return "Groceries"
        case .gas: return "Gas"
        case .travel: return "Travel"
        case .online: return "Online Shopping"
        case .entertainment: return "Entertainment"
        case .drugstore: return "Drugstores"
        case .home_improvement: return "Home Improvement"
        case .wholesale: return "Wholesale Clubs"
        case .streaming: return "Streaming Services"
        case .transportation: return "Transportation"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .dining: return "fork.knife"
        case .grocery: return "cart"
        case .gas: return "fuelpump"
        case .travel: return "airplane"
        case .online: return "globe"
        case .entertainment: return "ticket"
        case .drugstore: return "cross.case"
        case .home_improvement: return "hammer"
        case .wholesale: return "shippingbox"
        case .streaming: return "tv"
        case .transportation: return "car"
        case .other: return "bag"
        }
    }
}

// MARK: - Merchant Detection Result

struct MerchantDetection {
    let merchant: Merchant
    let confidence: Float       // 0.0 to 1.0
    let detectionMethod: DetectionMethod
    let timestamp: Date

    enum DetectionMethod: String {
        case logo = "logo"
        case text = "text"
        case location = "location"
        case domain = "domain"
        case manual = "manual"
    }
}

// MARK: - Preset Merchants

extension Merchant {
    static let presetMerchants: [Merchant] = [
        // Online Shopping
        Merchant(
            id: "amazon",
            name: "Amazon",
            displayName: "Amazon",
            primaryCategory: .online,
            logoName: "logo_amazon",
            domains: ["amazon.com", "amazon.co.uk", "amazon.ca"],
            aliases: ["Amazon.com", "Amazon Prime"],
            commonKeywords: ["amazon", "prime", "your order"]
        ),

        Merchant(
            id: "walmart",
            name: "Walmart",
            displayName: "Walmart",
            primaryCategory: .online,
            subCategories: [.grocery],
            logoName: "logo_walmart",
            domains: ["walmart.com"],
            aliases: ["Wal-Mart", "Walmart.com"],
            commonKeywords: ["walmart", "save money live better"]
        ),

        Merchant(
            id: "target",
            name: "Target",
            displayName: "Target",
            primaryCategory: .online,
            subCategories: [.grocery],
            logoName: "logo_target",
            domains: ["target.com"],
            aliases: ["Target.com"],
            commonKeywords: ["target", "expect more pay less"]
        ),

        // Dining
        Merchant(
            id: "starbucks",
            name: "Starbucks",
            displayName: "Starbucks",
            primaryCategory: .dining,
            logoName: "logo_starbucks",
            domains: ["starbucks.com"],
            aliases: ["Starbucks Coffee"],
            commonKeywords: ["starbucks", "coffee", "venti", "grande"]
        ),

        Merchant(
            id: "mcdonalds",
            name: "McDonalds",
            displayName: "McDonald's",
            primaryCategory: .dining,
            logoName: "logo_mcdonalds",
            domains: ["mcdonalds.com"],
            aliases: ["McDonald's", "McD"],
            commonKeywords: ["mcdonald", "mcdonalds", "i'm lovin it"]
        ),

        // Grocery
        Merchant(
            id: "whole_foods",
            name: "Whole Foods",
            displayName: "Whole Foods Market",
            primaryCategory: .grocery,
            logoName: "logo_wholefoods",
            domains: ["wholefoodsmarket.com"],
            aliases: ["Whole Foods Market", "WFM"],
            commonKeywords: ["whole foods", "wholefood", "365"]
        ),

        Merchant(
            id: "kroger",
            name: "Kroger",
            displayName: "Kroger",
            primaryCategory: .grocery,
            logoName: "logo_kroger",
            domains: ["kroger.com"],
            aliases: ["Kroger's"],
            commonKeywords: ["kroger", "fresh for everyone"]
        ),

        // Gas Stations
        Merchant(
            id: "shell",
            name: "Shell",
            displayName: "Shell",
            primaryCategory: .gas,
            logoName: "logo_shell",
            domains: ["shell.com"],
            aliases: ["Shell Gas", "Shell Station"],
            commonKeywords: ["shell", "v-power"]
        ),

        Merchant(
            id: "exxon",
            name: "Exxon",
            displayName: "Exxon Mobil",
            primaryCategory: .gas,
            logoName: "logo_exxon",
            domains: ["exxonmobil.com"],
            aliases: ["ExxonMobil", "Exxon", "Mobil"],
            commonKeywords: ["exxon", "mobil", "synergy"]
        ),

        // Transportation
        Merchant(
            id: "uber",
            name: "Uber",
            displayName: "Uber",
            primaryCategory: .transportation,
            subCategories: [.travel],
            logoName: "logo_uber",
            domains: ["uber.com"],
            aliases: ["Uber Rides", "UberEats"],
            commonKeywords: ["uber", "ride", "your ride"]
        ),

        Merchant(
            id: "lyft",
            name: "Lyft",
            displayName: "Lyft",
            primaryCategory: .transportation,
            subCategories: [.travel],
            logoName: "logo_lyft",
            domains: ["lyft.com"],
            aliases: ["Lyft Rides"],
            commonKeywords: ["lyft", "ride", "your ride"]
        ),

        // Home Improvement
        Merchant(
            id: "home_depot",
            name: "Home Depot",
            displayName: "The Home Depot",
            primaryCategory: .home_improvement,
            logoName: "logo_homedepot",
            domains: ["homedepot.com"],
            aliases: ["The Home Depot", "HD"],
            commonKeywords: ["home depot", "more saving more doing"]
        ),

        // Wholesale
        Merchant(
            id: "costco",
            name: "Costco",
            displayName: "Costco",
            primaryCategory: .wholesale,
            subCategories: [.gas, .grocery],
            logoName: "logo_costco",
            domains: ["costco.com"],
            aliases: ["Costco Wholesale"],
            commonKeywords: ["costco", "wholesale", "kirkland"]
        ),

        // Drugstores
        Merchant(
            id: "cvs",
            name: "CVS",
            displayName: "CVS Pharmacy",
            primaryCategory: .drugstore,
            logoName: "logo_cvs",
            domains: ["cvs.com"],
            aliases: ["CVS/pharmacy", "CVS Health"],
            commonKeywords: ["cvs", "pharmacy", "extracare"]
        ),

        Merchant(
            id: "walgreens",
            name: "Walgreens",
            displayName: "Walgreens",
            primaryCategory: .drugstore,
            logoName: "logo_walgreens",
            domains: ["walgreens.com"],
            aliases: ["Walgreens Pharmacy"],
            commonKeywords: ["walgreens", "at the corner"]
        )
    ]

    static func findByDomain(_ domain: String) -> Merchant? {
        let cleanDomain = domain.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")

        return presetMerchants.first { merchant in
            merchant.domains.contains { $0.contains(cleanDomain) || cleanDomain.contains($0) }
        }
    }

    static func findByKeyword(_ text: String) -> Merchant? {
        let lowerText = text.lowercased()

        // Check exact name matches first
        if let exact = presetMerchants.first(where: { lowerText.contains($0.name.lowercased()) }) {
            return exact
        }

        // Check aliases
        if let aliasMatch = presetMerchants.first(where: { merchant in
            merchant.aliases.contains { lowerText.contains($0.lowercased()) }
        }) {
            return aliasMatch
        }

        // Check keywords
        return presetMerchants.first { merchant in
            merchant.commonKeywords.contains { lowerText.contains($0.lowercased()) }
        }
    }
}