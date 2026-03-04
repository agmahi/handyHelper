import Foundation
import Vision
import CoreImage
import MWDATCamera
import UIKit

struct Detection: Identifiable {
    let id = UUID()
    let label: String
    let boundingBox: CGRect // Normalized 0.0 to 1.0
}

protocol PartDetectionDelegate: AnyObject {
    func partDetectionService(_ service: PartDetectionService, didUpdateDetections detections: [Detection])
}

class PartDetectionService: NSObject {
    weak var delegate: PartDetectionDelegate?
    
    // CoreML Request (Placeholder for YOLOv8 IKEA Model)
    private var objectDetectionRequest: VNCoreMLRequest?
    
    override init() {
        super.init()
        setupYOLO()
    }
    
    private func setupYOLO() {
        // Dynamically load YOLOv8 CoreML model if it exists in the bundle
        // This prevents build errors before you add the .mlpackage
        guard let modelURL = Bundle.main.url(forResource: "yolov8n", withExtension: "mlmodelc") else {
            print("YOLO model not found in bundle. Using fallback Vision text/rect detection.")
            return
        }
        
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .all
            let mlModel = try MLModel(contentsOf: modelURL, configuration: config)
            let vnModel = try VNCoreMLModel(for: mlModel)
            
            let request = VNCoreMLRequest(model: vnModel) { request, error in
                // Handled synchronously below in processFrame
            }
            request.imageCropAndScaleOption = .scaleFill
            self.objectDetectionRequest = request
            print("Successfully loaded YOLO CoreML model.")
        } catch {
            print("Failed to load YOLO CoreML model: \(error)")
        }
    }
    
    // Text Request (For OCR on IKEA part numbers)
    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            // Handle results later in processFrame to combine them
        }
        request.recognitionLevel = .accurate
        return request
    }()
    
    // Rectangle/Shape Request (For generic part detection)
    private lazy var rectRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            // Handle results later in processFrame to combine them
        }
        request.maximumObservations = 5
        return request
    }()
    
        func processFrame(_ videoFrame: VideoFrame) {
            guard let uiImage = videoFrame.makeUIImage(), let cgImage = uiImage.cgImage else { return }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                var allDetections: [Detection] = []
                
                if let yoloRequest = objectDetectionRequest {
                    // Run YOLO Object Detection
                    try handler.perform([yoloRequest])
                    
                    if let results = yoloRequest.results as? [VNRecognizedObjectObservation] {
                        for obs in results {
                            if let topLabel = obs.labels.first, topLabel.confidence > 0.4 {
                                allDetections.append(Detection(label: topLabel.identifier, boundingBox: obs.boundingBox))
                            }
                        }
                    }
                } else {
                    // Fallback: Run OCR and generic rectangle detection in parallel
                    try handler.perform([textRequest, rectRequest])
                    
                    // Extract text
                    if let textResults = textRequest.results as? [VNRecognizedTextObservation] {
                        for obs in textResults {
                            if let candidate = obs.topCandidates(1).first {
                                // For MVP Debugging, show ALL detected text, not just part numbers
                                allDetections.append(Detection(label: candidate.string, boundingBox: obs.boundingBox))
                            }
                        }
                    }
                    
                    // Extract rectangles
                    if let rectResults = rectRequest.results as? [VNRectangleObservation] {
                        for obs in rectResults {
                            allDetections.append(Detection(label: "Panel", boundingBox: obs.boundingBox))
                        }
                    }
                }
                
                Task { @MainActor in
                    self.delegate?.partDetectionService(self, didUpdateDetections: allDetections)
                }
                
            } catch {
                print("Vision frame processing failed: \(error)")
            }
        }    
    private func processDetectedStrings(_ strings: [String]) {
        // Look for IKEA-style part numbers (e.g. 101.352.21 or 101352)
        let parts = strings.filter { text in
            let isPartNumber = text.range(of: #"\d{3,}"#, options: .regularExpression) != nil
            return isPartNumber
        }
        
        if !parts.isEmpty {
            let detections = parts.map { Detection(label: $0, boundingBox: .zero) }
            Task { @MainActor in
                delegate?.partDetectionService(self, didUpdateDetections: detections)
            }
        }
    }
}
