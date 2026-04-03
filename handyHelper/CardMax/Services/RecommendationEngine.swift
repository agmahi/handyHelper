import Foundation

// MARK: - Recommendation Result

struct CardRecommendation {
    let card: CreditCard
    let merchant: Merchant?
    let category: MerchantCategory
    let rewardRate: Float
    let estimatedSavings: Decimal?
    let confidence: Float
    let reason: String

    var spokenResponse: String {
        let ownerPrefix = card.owner == "Me" ? "" : "\(card.owner)'s "
        if let merchant = merchant {
            return "\(ownerPrefix)\(card.nickname), \(formattedRate) at \(merchant.displayName)"
        } else {
            return "\(ownerPrefix)\(card.nickname), \(formattedRate) on \(category.displayName)"
        }
    }

    private var formattedRate: String {
        if rewardRate == Float(Int(rewardRate)) {
            return "\(Int(rewardRate))% back"
        } else {
            return String(format: "%.1f%% back", rewardRate)
        }
    }
}

// MARK: - Recommendation Engine

class RecommendationEngine {

    // MARK: - Recommend by Merchant

    func recommend(
        for merchant: Merchant,
        from cards: [CreditCard],
        purchaseAmount: Decimal? = nil
    ) -> CardRecommendation? {
        let activeCards = cards.filter { $0.isActive }
        guard !activeCards.isEmpty else { return nil }

        let scored = activeCards.map { card in
            let rate = rewardRate(card: card, merchant: merchant)
            return (card: card, rate: rate)
        }

        guard let best = scored.max(by: { $0.rate < $1.rate }) else { return nil }

        let savings = purchaseAmount.map { $0 * Decimal(Double(best.rate)) / 100 }

        return CardRecommendation(
            card: best.card,
            merchant: merchant,
            category: merchant.primaryCategory,
            rewardRate: best.rate,
            estimatedSavings: savings,
            confidence: 0.95,
            reason: "\(best.card.owner == "Me" ? "" : "\(best.card.owner)'s ")\(best.card.nickname) earns \(Int(best.rate))% on \(merchant.primaryCategory.displayName)"
        )
    }

    // MARK: - Recommend by Category (fallback when no merchant detected)

    func recommend(
        forCategory category: MerchantCategory,
        from cards: [CreditCard],
        purchaseAmount: Decimal? = nil
    ) -> CardRecommendation? {
        let activeCards = cards.filter { $0.isActive }
        guard !activeCards.isEmpty else { return nil }

        let scored = activeCards.map { card in
            let rate = card.effectiveCategoryRewards[category] ?? card.defaultRate
            return (card: card, rate: rate)
        }

        guard let best = scored.max(by: { $0.rate < $1.rate }) else { return nil }

        let savings = purchaseAmount.map { $0 * Decimal(Double(best.rate)) / 100 }

        return CardRecommendation(
            card: best.card,
            merchant: nil,
            category: category,
            rewardRate: best.rate,
            estimatedSavings: savings,
            confidence: 0.85,
            reason: "\(best.card.owner == "Me" ? "" : "\(best.card.owner)'s ")\(best.card.nickname) earns \(Int(best.rate))% on \(category.displayName)"
        )
    }

    // MARK: - Rate Calculation

    private func rewardRate(card: CreditCard, merchant: Merchant) -> Float {
        // 1. Check merchant-specific bonuses (highest priority)
        if let merchantBonus = card.merchantBonuses[merchant.id] {
            return merchantBonus
        }

        let effective = card.effectiveCategoryRewards

        // 2. Check primary category (includes active rotating categories)
        if let categoryRate = effective[merchant.primaryCategory] {
            return categoryRate
        }

        // 3. Check subcategories
        for sub in merchant.subCategories {
            if let subRate = effective[sub] {
                return subRate
            }
        }

        // 4. Fall back to default rate
        return card.defaultRate
    }
}
