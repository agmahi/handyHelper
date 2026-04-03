import Foundation
import Speech
import AVFoundation
import Combine

protocol SpeechRecognizerDelegate: AnyObject {
    func didHearCommand(_ command: NavigationCommand)
}

enum NavigationCommand {
    case next
    case back
    case `repeat`
}

class SpeechRecognizerService: ObservableObject {
    weak var delegate: SpeechRecognizerDelegate?
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isListening = false
    @Published var permissionError: String? = nil
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.permissionError = nil
                case .denied:
                    self?.permissionError = "User denied access to speech recognition"
                case .restricted:
                    self?.permissionError = "Speech recognition restricted on this device"
                case .notDetermined:
                    self?.permissionError = "Speech recognition not yet authorized"
                @unknown default:
                    self?.permissionError = "Unknown authorization error"
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.permissionError = "Microphone permission denied"
                }
            }
        }
    }
    
    func startListening() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            permissionError = "Speech recognizer is not available right now."
            return
        }
        
        if audioEngine.isRunning {
            stopListening()
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // We use .playAndRecord to allow both our AVSpeechSynthesizer to speak
            // and our microphone to listen. We route it to bluetooth if available.
            try audioSession.setCategory(.playAndRecord, mode: .videoChat, options: [.allowBluetoothHFP, .allowBluetoothA2DP, .defaultToSpeaker])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            
            // Keep only partial results so we can act immediately
            recognitionRequest.shouldReportPartialResults = true
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            DispatchQueue.main.async {
                self.isListening = true
            }
            
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    self.processTranscription(text)
                }
                
                if error != nil || result?.isFinal == true {
                    self.stopListening()
                    // Auto-restart listening if it drops
                    if error == nil {
                        self.startListening()
                    }
                }
            }
        } catch {
            permissionError = "Audio Engine setup failed: \(error.localizedDescription)"
            stopListening()
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
        
        DispatchQueue.main.async {
            self.isListening = false
        }
    }
    
    private func processTranscription(_ text: String) {
        // We look for specific keywords at the end of the transcription
        // to avoid constantly triggering on old words in the buffer.
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        guard let lastWord = words.last else { return }
        
        // Sometimes the recognizer joins words, so we check suffixes or exact matches
        if lastWord.contains("next") || text.hasSuffix("next step") {
            triggerCommand(.next)
        } else if lastWord.contains("back") || text.hasSuffix("previous") {
            triggerCommand(.back)
        } else if lastWord.contains("repeat") || text.hasSuffix("again") {
            triggerCommand(.repeat)
        }
    }
    
    private var lastTriggerTime: Date = .distantPast
    
    private func triggerCommand(_ command: NavigationCommand) {
        // Debounce triggers (prevent multiple fires within 2 seconds)
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > 2.0 else { return }
        lastTriggerTime = now
        
        DispatchQueue.main.async {
            self.delegate?.didHearCommand(command)
        }
        
        // Reset the recognizer task to clear the text buffer so it doesn't keep triggering
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.startListening()
        }
    }
}
