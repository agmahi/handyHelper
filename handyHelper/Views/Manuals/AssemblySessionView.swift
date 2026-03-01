import SwiftUI
import AVFoundation

struct AssemblySessionView: View {
    let manual: FurnitureManual
    @ObservedObject var manager: ManualManager
    @State private var currentStepIndex = 0
    @Environment(\.dismiss) var dismiss
    
    private let synthesizer = AVSpeechSynthesizer()
    
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
            speakCurrentStep()
        }
    }
    
    private func moveNext() {
        if currentStepIndex < manual.steps.count {
            currentStepIndex += 1
            speakCurrentStep()
        }
    }
    
    private func moveBack() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
            speakCurrentStep()
        }
    }
    
    private func speakCurrentStep() {
        guard let step = currentStep else { return }
        let utterance = AVSpeechUtterance(string: step.audioPrompt)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        // This will automatically route to glasses if they are the active audio output
        synthesizer.speak(utterance)
    }
}
