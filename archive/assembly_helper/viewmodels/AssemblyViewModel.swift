import Foundation
import Combine
import AVFoundation
import MWDATCamera
import MWDATCore
import UIKit

@MainActor
class AssemblyViewModel: ObservableObject, PartDetectionDelegate, SpeechRecognizerDelegate {
    let manual: FurnitureManual
    let manager: ManualManager
    private let wearables: WearablesInterface
    var onDismiss: (() -> Void)?
    
    @Published var currentStepIndex = 0
    @Published var steps: [AssemblyStep] = []
    @Published var currentPOVFrame: UIImage?
    @Published var detections: [Detection] = []
    @Published var detectedPartsBuffer: Set<String> = []
    @Published var streamError: String?
    @Published var isConnecting = true
    @Published var speechService = SpeechRecognizerService()
    
    private let streamSession: StreamSession
    private let deviceSelector: AutoDeviceSelector
    private let detectionService = PartDetectionService()
    private var frameListener: AnyListenerToken?
    private var stateListener: AnyListenerToken?
    private var deviceMonitorTask: Task<Void, Never>?
    private let synthesizer = AVSpeechSynthesizer()
    
    init(manual: FurnitureManual, manager: ManualManager, wearables: WearablesInterface, onDismiss: (() -> Void)? = nil) {
        self.manual = manual
        self.manager = manager
        self.wearables = wearables
        self.onDismiss = onDismiss
        self.steps = manual.steps
        
        // Setup exactly like Meta Sample
        self.deviceSelector = AutoDeviceSelector(wearables: wearables)
        let config = StreamSessionConfig(videoCodec: .raw, resolution: .low, frameRate: 24)
        self.streamSession = StreamSession(streamSessionConfig: config, deviceSelector: deviceSelector)
        
        detectionService.delegate = self
        speechService.delegate = self
        speechService.requestAuthorization()
        
        setupListeners()
    }
    
    private func setupListeners() {
        // 1. Frame Listener
        frameListener = streamSession.videoFramePublisher.listen { [weak self] frame in
            let uiImage = frame.makeUIImage()
            Task { @MainActor in
                guard let self = self else { return }
                self.currentPOVFrame = uiImage
                self.isConnecting = false
                self.detectionService.processFrame(frame)
            }
        }
        
        // 2. State Listener
        stateListener = streamSession.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                if state == .streaming {
                    self?.isConnecting = false
                }
            }
        }
        
        // 3. Device Monitor - Auto Start
        deviceMonitorTask = Task { @MainActor in
            for await device in deviceSelector.activeDeviceStream() {
                if device != nil {
                    await self.startSessionInternal()
                }
            }
        }
    }
    
    func startSessionInternal() async {
        let permission = Permission.camera
        do {
            let status = try await wearables.checkPermissionStatus(permission)
            if status == .granted {
                await streamSession.start()
            } else {
                let requestStatus = try await wearables.requestPermission(permission)
                if requestStatus == .granted {
                    await streamSession.start()
                } else {
                    self.streamError = "Camera access denied"
                }
            }
        } catch {
            self.streamError = "SDK Error: \(error.localizedDescription)"
        }
        
        // Delay our app's TTS so it doesn't overlap with the Meta hardware's "Experience Started" prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.speakCurrentStep()
        }
    }
    
    func exit() {
        stopSession()
        onDismiss?()
    }
    
    func stopSession() {
        deviceMonitorTask?.cancel()
        frameListener = nil
        stateListener = nil
        speechService.stopListening()
        Task {
            await streamSession.stop()
        }
    }
    
    var currentStep: AssemblyStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    func moveNext() {
        if currentStepIndex < steps.count {
            currentStepIndex += 1
            detectedPartsBuffer.removeAll()
            detections = []
            speakCurrentStep()
        }
    }
    
    func moveBack() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            detectedPartsBuffer.removeAll()
            detections = []
            speakCurrentStep()
        }
    }
    
    func speakCurrentStep() {
        guard let step = currentStep else { return }
        let utterance = AVSpeechUtterance(string: step.audioPrompt)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
        
        // Start listening for voice commands immediately after the TTS prompt finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.speechService.startListening()
        }
    }
    
    // MARK: - SpeechRecognizerDelegate
    func didHearCommand(_ command: VoiceCommand) {
        switch command {
        case .next:
            moveNext()
        case .back:
            moveBack()
        case .repeat:
            speakCurrentStep()
        }
    }
    
    // MARK: - PartDetectionDelegate
    func partDetectionService(_ service: PartDetectionService, didUpdateDetections detections: [Detection]) {
        self.detections = detections
        
        // MVP Testing Logic: If we see ANY text, we'll pretend it's a part to prove the audio loop works.
        guard let requiredParts = currentStep?.requiredParts else { return }
        
        // If there are no required parts (e.g. mock step), just use any detection to trigger the audio for testing
        let needsMockTrigger = requiredParts.isEmpty && !detections.isEmpty && detections.contains { $0.label != "Panel" }
        
        var foundMatch = false
        
        for detection in detections {
            let part = detection.label
            if requiredParts.contains(where: { part.contains($0) }) || needsMockTrigger {
                if !detectedPartsBuffer.contains(part) {
                    detectedPartsBuffer.insert(part)
                    foundMatch = true
                }
            }
        }
        
        if foundMatch {
            let feedback = AVSpeechUtterance(string: "I see you found it.")
            feedback.rate = 0.6
            synthesizer.speak(feedback)
            
            // Auto advance
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.moveNext()
            }
        }
    }
}
