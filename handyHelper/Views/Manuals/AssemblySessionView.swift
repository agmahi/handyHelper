import SwiftUI
import AVFoundation
import MWDATCamera
import MWDATCore

enum AssemblyViewMode: String, CaseIterable {
    case split = "Split"
    case pov = "POV"
    case manual = "Manual"
}

struct AssemblySessionView: View {
    @StateObject var viewModel: AssemblyViewModel
    @Environment(\.dismiss) var dismiss
    @State private var viewMode: AssemblyViewMode = .split
    
    var body: some View {
        VStack(spacing: 10) {
            // View Mode Picker
            Picker("View Mode", selection: $viewMode) {
                ForEach(AssemblyViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .animation(.easeInOut, value: viewMode)
            
            // Live POV Preview + Overlay
            if viewMode == .split || viewMode == .pov {
                povView
                    .frame(maxHeight: viewMode == .pov ? .infinity : 250)
            }

            // Progress Bar
            ProgressView(value: Double(viewModel.currentStepIndex + 1), total: Double(max(1, viewModel.steps.count)))
                .padding(.horizontal)
            
            if let step = viewModel.currentStep {
                if viewMode == .split || viewMode == .manual {
                    manualView(step: step)
                        .frame(maxHeight: viewMode == .manual ? .infinity : .infinity)
                }
                
                HStack(spacing: 40) {
                    Button(action: { viewModel.moveBack() }) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(viewModel.currentStepIndex > 0 ? .blue : .gray)
                    }
                    .disabled(viewModel.currentStepIndex == 0)
                    
                    Button(action: { viewModel.speakCurrentStep() }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: { viewModel.moveNext() }) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.bottom, 20)
            } else {
                completionView
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") {
                    viewModel.exit()
                }
            }
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
    
    private var povView: some View {
        ZStack {
            if let image = viewModel.currentPOVFrame {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay(
                        GeometryReader { geo in
                            ForEach(viewModel.detections) { detection in
                                let rect = convert(detection.boundingBox, to: geo.size)
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 2)
                                    .frame(width: rect.width, height: rect.height)
                                    .offset(x: rect.minX, y: rect.minY)
                            }
                        }
                    )
            } else if let error = viewModel.streamError {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(Text(error).foregroundColor(.red).multilineTextAlignment(.center).padding())
            } else if viewModel.isConnecting {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .overlay(
                        VStack {
                            ProgressView()
                            Text("Connecting to Glasses...").foregroundColor(.secondary).font(.caption).padding(.top, 5)
                        }
                    )
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.1))
                    .overlay(Text("Waiting for Glasses POV...").foregroundColor(.secondary))
            }
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func manualView(step: AssemblyStep) -> some View {
        VStack {
            Text("Step \(step.id) of \(viewModel.steps.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let imageData = step.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
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
        }
    }
    
    private var completionView: some View {
        // Completion State
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 100))
                .foregroundColor(.green)
            Text("Assembly Complete!")
                .font(.title)
                .bold()
            
            Button(action: {
                viewModel.manager.completeAssembly(for: viewModel.manual)
                viewModel.stopSession()
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
    
    // Helper to convert normalized Vision coordinates to SwiftUI view coordinates
    private func convert(_ normalizedRect: CGRect, to size: CGSize) -> CGRect {
        let width = normalizedRect.width * size.width
        let height = normalizedRect.height * size.height
        let x = normalizedRect.minX * size.width
        let y = (1 - normalizedRect.maxY) * size.height
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
