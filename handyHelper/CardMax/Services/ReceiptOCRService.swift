import Foundation
import UIKit
import Vision

// MARK: - Receipt OCR Service

struct ReceiptOCRService {

    struct OCRResult {
        let merchantName: String?
        let category: MerchantCategory?
        let recommendedCard: String?
    }

    /// Runs OCR on a receipt image, extracts merchant name,
    /// then matches to a known merchant/category and recommends the best card.
    static func annotate(
        image: UIImage,
        userCards: [CreditCard]
    ) async -> OCRResult {
        let lines = await recognizeText(in: image)

        let merchantName = extractMerchant(from: lines)

        // Try to match merchant to our database
        var category: MerchantCategory?
        var recommendedCard: String?

        if let name = merchantName {
            if let merchant = Merchant.findByKeyword(name) {
                category = merchant.primaryCategory
                if let best = bestCard(for: merchant, cards: userCards) {
                    recommendedCard = best
                }
            } else {
                // Fuzzy match against all merchant keywords
                let lowerName = name.lowercased()
                for preset in Merchant.presetMerchants {
                    let allTerms = [preset.name.lowercased(), preset.displayName.lowercased()]
                        + preset.aliases.map { $0.lowercased() }
                        + preset.commonKeywords.map { $0.lowercased() }
                    if allTerms.contains(where: { lowerName.contains($0) || $0.contains(lowerName) }) {
                        category = preset.primaryCategory
                        if let best = bestCard(for: preset, cards: userCards) {
                            recommendedCard = best
                        }
                        break
                    }
                }
            }
        }

        return OCRResult(
            merchantName: merchantName,
            category: category,
            recommendedCard: recommendedCard
        )
    }

    // MARK: - Vision OCR

    private static func recognizeText(in image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                let lines = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("ReceiptOCR: Vision request failed - \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: - Merchant Extraction

    /// Merchant name is typically in the first few lines of a receipt.
    private static func extractMerchant(from lines: [String]) -> String? {
        let candidates = lines.prefix(8).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count < 3 { return false }
            if trimmed.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "(" || $0 == ")" || $0 == " " }) { return false }
            if trimmed.contains(where: { $0 == "$" }) { return false }
            if trimmed.lowercased().hasPrefix("tel") || trimmed.lowercased().hasPrefix("phone") { return false }
            if trimmed.contains("/") && trimmed.count < 12 { return false }
            return true
        }

        return candidates.first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Card Recommendation

    private static func bestCard(for merchant: Merchant, cards: [CreditCard]) -> String? {
        var bestRate: Float = 0
        var bestCard: CreditCard?

        for card in cards where card.isActive {
            if let bonus = card.merchantBonuses[merchant.id], bonus > bestRate {
                bestRate = bonus
                bestCard = card
            }

            let effective = card.effectiveCategoryRewards
            if let catRate = effective[merchant.primaryCategory], catRate > bestRate {
                bestRate = catRate
                bestCard = card
            }

            if card.defaultRate > bestRate {
                bestRate = card.defaultRate
                bestCard = card
            }
        }

        guard let card = bestCard else { return nil }
        return card.owner == "Me" ? card.nickname : "\(card.owner)'s \(card.nickname)"
    }
}
