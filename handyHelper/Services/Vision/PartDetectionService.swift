import Foundation
import Vision
import CoreImage
import MWDATCamera
import UIKit

protocol PartDetectionDelegate: AnyObject {
    func partDetectionService(_ service: PartDetectionService, didDetectParts parts: [String])
}

class PartDetectionService: NSObject {
    weak var delegate: PartDetectionDelegate?
    
    // CoreML Request (Placeholder for YOLOv8 IKEA Model)
    private var objectDetectionRequest: VNCoreMLRequest?
    
    // Text Request (For OCR on IKEA part numbers)
    private lazy var textRequest: VNRecognizeTextRequest = {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            let foundText = observations.compactMap { $0.topCandidates(1).first?.string }
            self?.processDetectedStrings(foundText)
        }
        request.recognitionLevel = .accurate
        return request
    }()
    
    // Rectangle/Shape Request (For generic part detection)
    private lazy var rectRequest: VNDetectRectanglesRequest = {
        return VNDetectRectanglesRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRectangleObservation], !observations.isEmpty else { return }
            // If we see rectangles, we treat them as generic "Panel" or "Board" for the MVP
            self?.delegate?.partDetectionService(self!, didDetectParts: ["generic_panel"])
        }
    }()
    
    func processFrame(_ videoFrame: VideoFrame) {
        guard let uiImage = videoFrame.makeUIImage(), let cgImage = uiImage.cgImage else { return }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            // We run OCR and generic rectangle detection in parallel
            try handler.perform([textRequest, rectRequest])
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
            delegate?.partDetectionService(self, didDetectParts: parts)
        }
    }
}
