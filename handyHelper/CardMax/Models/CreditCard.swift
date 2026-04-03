import Foundation

// MARK: - Rotating Category Schedule

struct RotatingSchedule: Codable, Hashable {
    let quarter: Int                  // 1-4
    let year: Int                     // 2026
    let categories: [MerchantCategory]
    let rate: Float                   // typically 5.0
}

extension RotatingSchedule {
    // Discover it 2026 (approximate — update when official schedule is announced)
    static let discover2026: [RotatingSchedule] = [
        RotatingSchedule(quarter: 1, year: 2026, categories: [.grocery, .drugstore], rate: 5.0),
        RotatingSchedule(quarter: 2, year: 2026, categories: [.gas, .transportation], rate: 5.0),
        RotatingSchedule(quarter: 3, year: 2026, categories: [.dining, .streaming], rate: 5.0),
        RotatingSchedule(quarter: 4, year: 2026, categories: [.online, .entertainment], rate: 5.0),
    ]

    // Chase Freedom Flex 2026 (approximate — update when official schedule is announced)
    static let freedomFlex2026: [RotatingSchedule] = [
        RotatingSchedule(quarter: 1, year: 2026, categories: [.grocery, .entertainment], rate: 5.0),
        RotatingSchedule(quarter: 2, year: 2026, categories: [.gas, .online], rate: 5.0),
        RotatingSchedule(quarter: 3, year: 2026, categories: [.dining, .streaming], rate: 5.0),
        RotatingSchedule(quarter: 4, year: 2026, categories: [.grocery, .gas], rate: 5.0),
    ]
}

// MARK: - Credit Card Model

struct CreditCard: Codable, Identifiable, Hashable {
    let id: UUID
    let nickname: String              // "Sapphire" (user-friendly name)
    let fullName: String              // "Chase Sapphire Preferred"
    let issuer: CardIssuer           // .chase
    let network: CardNetwork         // .visa
    let lastFourDigits: String       // "1234"

    // Reward Structure
    let defaultRate: Float           // 1.0 for 1%
    let categoryRewards: [MerchantCategory: Float]
    let merchantBonuses: [String: Float]  // Merchant ID -> bonus rate
    let rotatingCategories: [RotatingSchedule]

    // Ownership
    let owner: String                 // "Me", spouse name, etc.

    // Metadata
    let annualFee: Decimal
    let addedDate: Date
    let isActive: Bool
    let color: CardColor

    init(
        id: UUID = UUID(),
        nickname: String,
        fullName: String,
        issuer: CardIssuer,
        network: CardNetwork,
        lastFourDigits: String,
        defaultRate: Float,
        categoryRewards: [MerchantCategory: Float] = [:],
        merchantBonuses: [String: Float] = [:],
        rotatingCategories: [RotatingSchedule] = [],
        owner: String = "Me",
        annualFee: Decimal = 0,
        addedDate: Date = Date(),
        isActive: Bool = true,
        color: CardColor = .blue
    ) {
        self.id = id
        self.nickname = nickname
        self.fullName = fullName
        self.issuer = issuer
        self.network = network
        self.lastFourDigits = lastFourDigits
        self.defaultRate = defaultRate
        self.categoryRewards = categoryRewards
        self.merchantBonuses = merchantBonuses
        self.rotatingCategories = rotatingCategories
        self.owner = owner
        self.annualFee = annualFee
        self.addedDate = addedDate
        self.isActive = isActive
        self.color = color
    }

    /// Returns categoryRewards merged with any active rotating categories for the current quarter.
    /// Rotating rates override static rates when higher.
    var effectiveCategoryRewards: [MerchantCategory: Float] {
        var rewards = categoryRewards

        let (quarter, year) = Self.currentQuarter()
        let activeSchedules = rotatingCategories.filter { $0.quarter == quarter && $0.year == year }

        for schedule in activeSchedules {
            for category in schedule.categories {
                let existing = rewards[category] ?? 0
                if schedule.rate > existing {
                    rewards[category] = schedule.rate
                }
            }
        }

        return rewards
    }

    /// Returns the active rotating categories for the current quarter, if any.
    var activeRotatingCategories: (categories: [MerchantCategory], rate: Float)? {
        let (quarter, year) = Self.currentQuarter()
        guard let schedule = rotatingCategories.first(where: { $0.quarter == quarter && $0.year == year }) else {
            return nil
        }
        return (schedule.categories, schedule.rate)
    }

    private static func currentQuarter() -> (quarter: Int, year: Int) {
        let cal = Calendar.current
        let now = Date()
        let month = cal.component(.month, from: now)
        let year = cal.component(.year, from: now)
        let quarter = ((month - 1) / 3) + 1
        return (quarter, year)
    }
}

// MARK: - Card Issuer

enum CardIssuer: String, CaseIterable, Codable {
    case chase = "Chase"
    case amex = "American Express"
    case citi = "Citi"
    case capital_one = "Capital One"
    case discover = "Discover"
    case bank_of_america = "Bank of America"
    case wells_fargo = "Wells Fargo"
    case other = "Other"

    var displayName: String { rawValue }
}

// MARK: - Card Network

enum CardNetwork: String, CaseIterable, Codable {
    case visa = "Visa"
    case mastercard = "Mastercard"
    case amex = "American Express"
    case discover = "Discover"

    var displayName: String { rawValue }
}

// MARK: - Card Color

enum CardColor: String, CaseIterable, Codable {
    case blue = "blue"
    case gold = "gold"
    case silver = "silver"
    case black = "black"
    case red = "red"
    case green = "green"
    case purple = "purple"
    case orange = "orange"
    case coral = "coral"

    // Pocket Operator-inspired palette: muted base + signature bright accents
    var hexValue: String {
        switch self {
        case .blue: return "#3D7A8A"     // Muted teal (PO-14)
        case .gold: return "#C8893E"     // Warm amber/kraft
        case .silver: return "#A8A196"   // Warm gray (PO-35)
        case .black: return "#3A3632"    // Charcoal brown (PO-32)
        case .red: return "#E8392B"      // PO bright red (PO-28 display)
        case .green: return "#5A7247"    // Olive green (PO-12)
        case .purple: return "#8A5A6A"   // Muted burgundy/mauve (PO-16)
        case .orange: return "#FF6B2B"   // PO signature orange (knob/accent)
        case .coral: return "#FF4F58"    // PO hot coral (LED/display accent)
        }
    }
}

// MARK: - Preset Cards

extension CreditCard {
    static let presets: [CreditCard] = [
        // Chase Sapphire Preferred
        CreditCard(
            nickname: "Sapphire",
            fullName: "Chase Sapphire Preferred",
            issuer: .chase,
            network: .visa,
            lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [
                .dining: 3.0,
                .travel: 3.0,
                .streaming: 3.0,
                .online: 3.0
            ],
            annualFee: 95,
            color: .blue
        ),

        // Amex Gold
        CreditCard(
            nickname: "Amex Gold",
            fullName: "American Express Gold Card",
            issuer: .amex,
            network: .amex,
            lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [
                .dining: 4.0,
                .grocery: 4.0
            ],
            annualFee: 250,
            color: .gold
        ),

        // Citi Double Cash
        CreditCard(
            nickname: "Double Cash",
            fullName: "Citi Double Cash",
            issuer: .citi,
            network: .mastercard,
            lastFourDigits: "0000",
            defaultRate: 2.0,
            categoryRewards: [:],  // 2% on everything
            annualFee: 0,
            color: .blue
        ),

        // Amazon Prime Rewards
        CreditCard(
            nickname: "Amazon",
            fullName: "Amazon Prime Rewards Visa",
            issuer: .chase,
            network: .visa,
            lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [
                .gas: 2.0,
                .dining: 2.0,
                .drugstore: 2.0
            ],
            merchantBonuses: [
                "amazon": 5.0,
                "whole_foods": 5.0
            ],
            annualFee: 0,
            color: .black
        ),

        // Discover it
        CreditCard(
            nickname: "Discover",
            fullName: "Discover it Cash Back",
            issuer: .discover,
            network: .discover,
            lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [:],
            rotatingCategories: RotatingSchedule.discover2026,
            annualFee: 0,
            color: .silver
        )
    ]

    /// Full catalog of popular cards users can add to their wallet
    static let catalog: [CreditCard] = presets + [
        CreditCard(
            nickname: "Sapphire Reserve",
            fullName: "Chase Sapphire Reserve",
            issuer: .chase, network: .visa, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.dining: 3.0, .travel: 5.0, .streaming: 3.0],
            annualFee: 550, color: .black
        ),
        CreditCard(
            nickname: "Freedom Flex",
            fullName: "Chase Freedom Flex",
            issuer: .chase, network: .mastercard, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.dining: 3.0, .drugstore: 3.0, .travel: 5.0],
            rotatingCategories: RotatingSchedule.freedomFlex2026,
            annualFee: 0, color: .blue
        ),
        CreditCard(
            nickname: "Freedom Unlimited",
            fullName: "Chase Freedom Unlimited",
            issuer: .chase, network: .visa, lastFourDigits: "0000",
            defaultRate: 1.5,
            categoryRewards: [.dining: 3.0, .drugstore: 3.0],
            annualFee: 0, color: .blue
        ),
        CreditCard(
            nickname: "Amex Platinum",
            fullName: "American Express Platinum",
            issuer: .amex, network: .amex, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.travel: 5.0, .streaming: 1.0],
            annualFee: 695, color: .silver
        ),
        CreditCard(
            nickname: "Blue Cash Preferred",
            fullName: "Amex Blue Cash Preferred",
            issuer: .amex, network: .amex, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.grocery: 6.0, .streaming: 6.0, .gas: 3.0, .transportation: 3.0],
            annualFee: 95, color: .blue
        ),
        CreditCard(
            nickname: "Custom Cash",
            fullName: "Citi Custom Cash",
            issuer: .citi, network: .mastercard, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.dining: 5.0, .grocery: 5.0, .gas: 5.0, .travel: 5.0, .entertainment: 5.0, .streaming: 5.0],
            annualFee: 0, color: .purple
        ),
        CreditCard(
            nickname: "Venture X",
            fullName: "Capital One Venture X",
            issuer: .capital_one, network: .visa, lastFourDigits: "0000",
            defaultRate: 2.0,
            categoryRewards: [.travel: 5.0],
            annualFee: 395, color: .black
        ),
        CreditCard(
            nickname: "SavorOne",
            fullName: "Capital One SavorOne",
            issuer: .capital_one, network: .mastercard, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.dining: 3.0, .grocery: 3.0, .entertainment: 3.0, .streaming: 3.0],
            annualFee: 0, color: .green
        ),
        CreditCard(
            nickname: "Customized Cash",
            fullName: "Bank of America Customized Cash",
            issuer: .bank_of_america, network: .visa, lastFourDigits: "0000",
            defaultRate: 1.0,
            categoryRewards: [.dining: 3.0, .gas: 2.0, .online: 2.0],
            annualFee: 0, color: .red
        ),
        CreditCard(
            nickname: "Active Cash",
            fullName: "Wells Fargo Active Cash",
            issuer: .wells_fargo, network: .visa, lastFourDigits: "0000",
            defaultRate: 2.0,
            categoryRewards: [:],
            annualFee: 0, color: .red
        ),
    ]
}