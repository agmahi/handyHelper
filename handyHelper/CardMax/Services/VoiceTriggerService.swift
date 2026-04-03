import Foundation
import Speech
import AVFoundation
import Combine
import UIKit

// MARK: - Voice Command Types

enum VoiceCommand: Equatable {
    case whichCard
    case whichCardForCategory(MerchantCategory)
    case whichCardAtMerchant(String) // merchant name from speech
    case bestCard
    case unknown

    init(from text: String) {
        let lowercased = text.lowercased()

        // Check for "at <merchant>" pattern (e.g., "which card at Costco")
        for pattern in ["which card at ", "what card at ", "best card at ", "card at "] {
            if let range = lowercased.range(of: pattern) {
                let merchantName = String(lowercased[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !merchantName.isEmpty {
                    self = .whichCardAtMerchant(merchantName)
                    return
                }
            }
        }

        // Check for category-specific commands
        for category in MerchantCategory.allCases {
            let categoryPhrases = [
                "which card for \(category.rawValue)",
                "what card for \(category.rawValue)",
                "best card for \(category.rawValue)",
                "card for \(category.rawValue)"
            ]

            if categoryPhrases.contains(where: lowercased.contains) {
                self = .whichCardForCategory(category)
                return
            }
        }

        // Common category aliases in speech
        let categoryAliases: [(String, MerchantCategory)] = [
            ("food", .dining), ("restaurant", .dining), ("eating", .dining),
            ("groceries", .grocery), ("supermarket", .grocery),
            ("fuel", .gas), ("gasoline", .gas),
            ("flight", .travel), ("hotel", .travel),
            ("pharmacy", .drugstore),
        ]
        for (alias, category) in categoryAliases {
            if lowercased.contains("card for \(alias)") {
                self = .whichCardForCategory(category)
                return
            }
        }

        // Check for general trigger phrases
        if lowercased.contains("which card") || lowercased.contains("what card") {
            self = .whichCard
        } else if lowercased.contains("best card") {
            self = .bestCard
        } else {
            self = .unknown
        }
    }
}

// MARK: - Voice Trigger Delegate

protocol VoiceTriggerDelegate: AnyObject {
    func voiceTriggerActivated(command: VoiceCommand)
    func voiceTriggerError(_ error: Error)
}

// MARK: - Voice Trigger Service

@MainActor
class VoiceTriggerService: NSObject, ObservableObject {
    // Published properties for SwiftUI
    @Published var isListening = false
    @Published var lastTranscription = ""
    @Published var error: Error?

    // Delegate for command callbacks
    weak var delegate: VoiceTriggerDelegate?

    // Speech recognition components
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Trigger configuration
    private let triggerPhrases = [
        "which card",
        "what card",
        "best card",
        "card for"
    ]

    // Audio feedback
    private let audioFeedback = AudioFeedbackService()

    override init() {
        super.init()
        requestAuthorization()
    }

    // MARK: - Authorization

    private func requestAuthorization() {
        Task {
            // Request speech recognition permission
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    if status != .authorized {
                        self.error = VoiceTriggerError.notAuthorized
                    }
                }
            }

            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    if !granted {
                        self.error = VoiceTriggerError.microphoneNotAuthorized
                    }
                }
            }
        }
    }

    // MARK: - Start/Stop Listening

    func startListening() {
        guard !isListening else { return }

        do {
            try startRecognition()
            isListening = true
            print("CardMax: Voice trigger listening started")
        } catch {
            print("CardMax: Voice trigger failed to start - \(error.localizedDescription)")
            self.error = error
            delegate?.voiceTriggerError(error)
        }
    }

    func stopListening() {
        guard isListening else { return }

        isListening = false
        cleanupRecognition()

        print("CardMax: Voice trigger listening stopped")
    }

    // MARK: - Speech Recognition

    private func startRecognition() throws {
        // Fully tear down any previous session
        cleanupRecognition()

        // Configure audio session for voice recognition
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true // Use on-device for privacy
        recognitionRequest = request

        // Configure audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install audio tap
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        hasTapInstalled = true

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                self?.handleRecognitionResult(result, error: error)
            }
        }
    }

    private var hasTapInstalled = false

    /// Tears down recognition task and audio tap without changing isListening state.
    private func cleanupRecognition() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil

        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            hasTapInstalled = false
        }
        if audioEngine.isRunning {
            audioEngine.stop()
        }
    }

    // MARK: - Handle Recognition Results

    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            // Handle non-fatal errors gracefully
            if (error as NSError).code != 203 { // Ignore "No speech detected" errors
                self.error = error
                print("❌ Recognition error: \(error.localizedDescription)")
            }
            return
        }

        guard let result = result else { return }

        let transcription = result.bestTranscription.formattedString
        lastTranscription = transcription

        // Check for trigger phrases
        checkForTriggerPhrase(in: transcription)

        // If recognition is final, restart listening
        if result.isFinal {
            scheduleRestart()
        }
    }

    // MARK: - Trigger Detection

    private func checkForTriggerPhrase(in text: String) {
        let lowercased = text.lowercased()

        // Check if any trigger phrase is present
        let containsTrigger = triggerPhrases.contains { phrase in
            lowercased.contains(phrase)
        }

        if containsTrigger {
            // Parse the full command
            let command = VoiceCommand(from: text)

            if command != .unknown {
                print("✅ Trigger detected: \(text)")

                // Provide audio feedback
                audioFeedback.playActivationSound()

                // Notify delegate
                delegate?.voiceTriggerActivated(command: command)

                // Reset transcription after trigger
                lastTranscription = ""

                // Pause listening briefly to avoid double-triggers
                pauseListening()
            }
        }
    }

    // MARK: - Listening Control

    private var restartWorkItem: DispatchWorkItem?

    private func scheduleRestart(delay: TimeInterval = 0.3) {
        // Cancel any pending restart to prevent accumulation
        restartWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, self.isListening else { return }
            do {
                try self.startRecognition()
            } catch {
                self.error = error
                self.delegate?.voiceTriggerError(error)
            }
        }
        restartWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func pauseListening() {
        guard isListening else { return }
        cleanupRecognition()
        // Resume after delay (to avoid hearing our own audio response)
        scheduleRestart(delay: 3.0)
    }

    deinit {
        restartWorkItem?.cancel()
        if hasTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
    }
}

// MARK: - Voice Trigger Errors

enum VoiceTriggerError: LocalizedError {
    case notAuthorized
    case microphoneNotAuthorized
    case recognitionNotAvailable

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized. Please enable in Settings."
        case .microphoneNotAuthorized:
            return "Microphone access not authorized. Please enable in Settings."
        case .recognitionNotAvailable:
            return "Speech recognition is not available on this device."
        }
    }
}

// MARK: - Audio Feedback Service

class AudioFeedbackService {
    func playActivationSound() {
        AudioServicesPlaySystemSound(1104) // Tink sound

        #if canImport(UIKit)
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        #endif
    }
}