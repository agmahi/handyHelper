import Foundation
import UIKit
import MWDATCore
import MWDATCamera
import AVFoundation
import Combine

// MARK: - CardMax State Machine

enum CardMaxState: Equatable {
    case idle
    case detecting
    case recommending(CardRecommendation)
    case capturing
    case error(String)

    static func == (lhs: CardMaxState, rhs: CardMaxState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.detecting, .detecting), (.capturing, .capturing): return true
        case (.recommending, .recommending): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

// MARK: - CardMax ViewModel

@MainActor
class CardMaxViewModel: ObservableObject {
    // State
    @Published var state: CardMaxState = .idle
    @Published var isGlassesConnected = false
    @Published var lastRecommendation: CardRecommendation?

    // Receipt capture
    @Published var lastCapturedReceipt: UIImage?
    @Published var receipts: [Receipt] = ReceiptStorageService.load()

    // User's card portfolio (synced with shared service + persisted)
    @Published var userCards: [CreditCard] {
        didSet {
            service.userCards = userCards
            CardStorageService.save(userCards)
        }
    }

    // Services
    let audioResponse = AudioResponseService()
    let service: CardMaxService

    // Meta SDK
    private var deviceStreamTask: Task<Void, Never>?

    // MARK: - Init

    init(wearables: WearablesInterface) {
        self.service = CardMaxService.shared
        self.userCards = CardStorageService.load() ?? CreditCard.presets

        // Configure shared service with wearables SDK
        service.configure(wearables: wearables)

        // Monitor active device connection (not just paired)
        let deviceSelector = AutoDeviceSelector(wearables: wearables)
        deviceStreamTask = Task { @MainActor in
            for await device in deviceSelector.activeDeviceStream() {
                self.isGlassesConnected = device != nil
            }
        }
    }

    deinit {
        deviceStreamTask?.cancel()
    }

    // MARK: - Recommendation (called from Siri intent results)

    func recommendForMerchantName(_ name: String) {
        state = .detecting

        if let merchant = Merchant.findByKeyword(name) {
            if let rec = service.recommendationEngine.recommend(for: merchant, from: userCards) {
                presentRecommendation(rec)
                return
            }
        }

        if let category = MerchantCategory(rawValue: name) {
            recommendForCategory(category)
            return
        }

        state = .idle
    }

    func recommendForCategory(_ category: MerchantCategory) {
        if let recommendation = service.recommendForCategory(category) {
            presentRecommendation(recommendation)
        } else {
            state = .error("No cards available for \(category.displayName)")
        }
    }

    private func presentRecommendation(_ recommendation: CardRecommendation) {
        lastRecommendation = recommendation
        state = .recommending(recommendation)

        audioResponse.speakRecommendation(
            card: recommendation.card,
            merchant: recommendation.merchant,
            rewardRate: recommendation.rewardRate,
            category: recommendation.category
        ) { [weak self] in
            Task { @MainActor in
                self?.state = .idle
            }
        }
    }

    // MARK: - Receipt Capture

    /// Capture receipt via Meta glasses camera
    func captureReceipt() async {
        state = .capturing

        if let image = await service.capturePhoto() {
            saveReceipt(image: image)
            state = .idle
        } else {
            state = .error("Failed to capture photo")
        }
    }

    /// Save a receipt from any source (glasses, phone camera, photo library)
    /// Runs OCR annotation in the background after saving.
    func saveReceipt(image: UIImage) {
        lastCapturedReceipt = image
        var receipt = Receipt(image: image)
        receipts.insert(receipt, at: 0)
        ReceiptStorageService.save(receipts)

        // Run OCR in background, update receipt when done
        let cards = userCards
        Task {
            let result = await ReceiptOCRService.annotate(image: image, userCards: cards)
            if let index = receipts.firstIndex(where: { $0.id == receipt.id }) {
                receipts[index].merchantName = result.merchantName
                receipts[index].category = result.category
                receipts[index].recommendedCard = result.recommendedCard
                ReceiptStorageService.save(receipts)
            }
        }
    }

    func deleteReceipt(_ receipt: Receipt) {
        receipts.removeAll { $0.id == receipt.id }
        ReceiptStorageService.save(receipts)
        ReceiptStorageService.deleteImage(receipt.imageFileName)
    }

    // MARK: - Card Management

    func addCard(_ card: CreditCard) {
        // Same card name + same owner = duplicate
        guard !userCards.contains(where: { $0.fullName == card.fullName && $0.owner == card.owner }) else { return }
        userCards.append(card)
    }

    func removeCard(_ card: CreditCard) {
        userCards.removeAll { $0.id == card.id }
    }

    func updateCardColor(_ card: CreditCard, to newColor: CardColor) {
        guard let index = userCards.firstIndex(where: { $0.id == card.id }) else { return }
        let updated = CreditCard(
            id: card.id,
            nickname: card.nickname,
            fullName: card.fullName,
            issuer: card.issuer,
            network: card.network,
            lastFourDigits: card.lastFourDigits,
            defaultRate: card.defaultRate,
            categoryRewards: card.categoryRewards,
            merchantBonuses: card.merchantBonuses,
            rotatingCategories: card.rotatingCategories,
            owner: card.owner,
            annualFee: card.annualFee,
            addedDate: card.addedDate,
            isActive: card.isActive,
            color: newColor
        )
        userCards[index] = updated
    }

    // MARK: - Mock / Debug Support

    #if DEBUG
    func simulateDetection(merchant: Merchant) {
        if let recommendation = service.recommendationEngine.recommend(for: merchant, from: userCards) {
            presentRecommendation(recommendation)
        }
    }

    func simulateCategoryRecommendation(_ category: MerchantCategory) {
        recommendForCategory(category)
    }
    #endif
}
