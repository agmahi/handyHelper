import Foundation
import AVFoundation
import Combine

// MARK: - Audio Response Service

@MainActor
class AudioResponseService: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isSpeaking = false

    // MARK: - Private Properties

    private let synthesizer = AVSpeechSynthesizer()
    private var onSpeechFinished: (() -> Void)?

    private let speechRate: Float = 0.52
    private let speechPitch: Float = 1.05
    private let voiceLanguage = "en-US"

    // MARK: - Initialization

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    private func configureAudioSessionForSpeech() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth, .defaultToSpeaker]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioResponseService: Failed to configure audio session - \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    func speak(_ text: String, completion: (() -> Void)? = nil) {
        guard !text.isEmpty else {
            completion?()
            return
        }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        onSpeechFinished = completion

        configureAudioSessionForSpeech()
        let utterance = makeUtterance(for: text)
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func speakRecommendation(
        card: CreditCard,
        merchant: Merchant?,
        rewardRate: Float,
        category: MerchantCategory?,
        completion: (() -> Void)? = nil
    ) {
        let message = buildRecommendationMessage(
            card: card,
            merchant: merchant,
            rewardRate: rewardRate,
            category: category
        )
        speak(message, completion: completion)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - Message Generation

    private func buildRecommendationMessage(
        card: CreditCard,
        merchant: Merchant?,
        rewardRate: Float,
        category: MerchantCategory?
    ) -> String {
        let rateDescription = formatRate(rewardRate)

        if let merchant = merchant {
            return "Use your \(card.nickname), \(rateDescription) at \(merchant.displayName)."
        }

        if let category = category {
            return "Use your \(card.nickname), \(rateDescription) on \(category.displayName.lowercased())."
        }

        return "Use your \(card.nickname), \(rateDescription) on this purchase."
    }

    private func formatRate(_ rate: Float) -> String {
        let isWholeNumber = rate == Float(Int(rate))
        if isWholeNumber {
            let intRate = Int(rate)
            return intRate <= 3 ? "\(intRate)% back" : "\(intRate)x points"
        } else {
            return String(format: "%.1f%% back", rate)
        }
    }

    // MARK: - Utterance Factory

    private lazy var preferredVoice: AVSpeechSynthesisVoice? = {
        // Try premium/enhanced voices first for natural-sounding speech
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-US") }
            .sorted { $0.quality.rawValue > $1.quality.rawValue }

        // Pick the highest quality available
        return voices.first ?? AVSpeechSynthesisVoice(language: voiceLanguage)
    }()

    private func makeUtterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.pitchMultiplier = speechPitch
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1
        utterance.voice = preferredVoice
        return utterance
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioResponseService: AVSpeechSynthesizerDelegate {

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            let callback = self.onSpeechFinished
            self.onSpeechFinished = nil
            callback?()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.isSpeaking = false
            let callback = self.onSpeechFinished
            self.onSpeechFinished = nil
            callback?()
        }
    }
}
