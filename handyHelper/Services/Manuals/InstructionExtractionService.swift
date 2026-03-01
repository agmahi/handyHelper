import Foundation
import PDFKit
import Vision
import CoreImage

class InstructionExtractionService {
    
    enum ExtractionError: Error {
        case emptyDocument
        case processingFailed
    }
    
    /// Extracts steps from a PDF document by analyzing pages with Vision framework.
    func extractSteps(from document: PDFDocument) async throws -> [AssemblyStep] {
        guard document.pageCount > 0 else { throw ExtractionError.emptyDocument }
        
        var steps: [AssemblyStep] = []
        
        // Process up to 5 pages for the MVP to keep it fast
        let pageLimit = min(document.pageCount, 5)
        
        for i in 0..<pageLimit {
            guard let page = document.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let img = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            
            guard let cgImage = img.cgImage else { continue }
            
            // Extract text using Vision
            let extractedText = await extractText(from: cgImage)
            
            let instructionText = extractedText.isEmpty ? "Review the diagram for step \(i + 1)." : extractedText
            let audioPrompt = extractedText.isEmpty ? "Please review the diagram shown on screen." : extractedText
            
            let step = AssemblyStep(
                id: i + 1,
                instruction: instructionText,
                imageName: nil,
                imageData: img.jpegData(compressionQuality: 0.8),
                audioPrompt: audioPrompt
            )
            steps.append(step)
        }
        
        return steps
    }
    
    private func extractText(from cgImage: CGImage) async -> String {
        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    continuation.resume(returning: "")
                    return
                }
                
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
                continuation.resume(returning: text)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: "")
            }
        }
    }
}
