import SwiftUI
import AVFoundation
import MWDATCamera
import MWDATCore

struct AssemblySessionView: View {
    let manual: FurnitureManual
    @ObservedObject var manager: ManualManager
    @State private var currentStepIndex = 0
    @Environment(\.dismiss) var dismiss
    
    // Meta SDK Stream Integration
    private let streamSession: StreamSession
    private let detectionService = PartDetectionService()
    @State private var frameListener: AnyListenerToken?
    @State private var detectedPartsBuffer: Set<String> = []
    
    private let synthesizer = AVSpeechSynthesizer()
    
    init(manual: FurnitureManual, manager: ManualManager) {
        self.manual = manual
        self.manager = manager
        
        // Use the default selector to grab the glasses' feed
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        let config = StreamSessionConfig(videoCodec: .raw, resolution: .low, frameRate: 15)
        self.streamSession = StreamSession(streamSessionConfig: config, deviceSelector: selector)
    }
    
    var currentStep: AssemblyStep? {
        guard currentStepIndex < manual.steps.count else { return nil }
        return manual.steps[currentStepIndex]
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Progress Bar
            ProgressView(value: Double(currentStepIndex + 1), total: Double(manual.steps.count))
                .padding()
            
            if let step = currentStep {
                Text("Step \(step.id) of \(manual.steps.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let imageData = step.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .padding()
                } else if let imageName = step.imageName {
                    Image(systemName: imageName)
                        .font(.system(size: 100))
                        .foregroundColor(.blue)
                        .frame(height: 200)
                }
                
                Text(step.instruction)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
                
                HStack(spacing: 40) {
                    Button(action: { moveBack() }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(currentStepIndex > 0 ? .blue : .gray)
                    }
                    .disabled(currentStepIndex == 0)
                    
                    Button(action: { speakCurrentStep() }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { moveNext() }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 50)
            } else {
                // Completion State
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.green)
                    Text("Assembly Complete!")
                        .font(.title)
                        .bold()
                    
                    Button(action: {
                        manager.completeAssembly(for: manual)
                        dismiss()
                    }) {
                        Text("Save to History & Exit")
                            .bold()
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") { dismiss() }
            }
        }
        .onAppear {
            startVisionSession()
            speakCurrentStep()
        }
        .onDisappear {
            stopVisionSession()
        }
    }
    
    private func startVisionSession() {
        detectionService.delegate = self
        
        // Start Meta Camera Stream
        Task {
            await streamSession.start()
            
            // Tap the frame publisher
            frameListener = streamSession.videoFramePublisher.listen { frame in
                detectionService.processFrame(frame)
            }
        }
    }
    
    private func stopVisionSession() {
        Task {
            await streamSession.stop()
            frameListener = nil
        }
    }
    
    private func moveNext() {
        if currentStepIndex < manual.steps.count {
            currentStepIndex += 1
            detectedPartsBuffer.removeAll() // Reset buffer for next step
            speakCurrentStep()
        }
    }
    
    private func moveBack() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            detectedPartsBuffer.removeAll()
            speakCurrentStep()
        }
    }
    
    private func speakCurrentStep() {
        guard let step = currentStep else { return }
        let utterance = AVSpeechUtterance(string: step.audioPrompt)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        synthesizer.speak(utterance)
    }
}

// MARK: - PartDetectionDelegate (The Validation Engine)
extension AssemblySessionView: PartDetectionDelegate {
    func partDetectionService(_ service: PartDetectionService, didDetectParts parts: [String]) {
        guard let requiredParts = currentStep?.requiredParts, !requiredParts.isEmpty else { return }
        
        for part in parts {
            // Check if the detected part matches any required part for the current step
            // We use fuzzy matching for MVP (contains)
            if requiredParts.contains(where: { part.contains($0) }) {
                if !detectedPartsBuffer.contains(part) {
                    detectedPartsBuffer.insert(part)
                    
                    // Audio Feedback: Confirmation
                    let feedback = AVSpeechUtterance(string: "I see you found it.")
                    feedback.rate = 0.6
                    synthesizer.speak(feedback)
                    
                    // Logic: If all required parts are found, auto-advance or signal
                    // For MVP: Auto-advance after a 2-second delay to let the user finish looking
                    if detectedPartsBuffer.count >= requiredParts.count {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            self.moveNext()
                        }
                    }
                }
            }
        }
    }
}
