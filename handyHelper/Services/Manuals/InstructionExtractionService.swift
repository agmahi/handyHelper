import Foundation
import PDFKit
import CoreImage

class InstructionExtractionService {
    
    enum ExtractionError: Error {
        case emptyDocument
        case processingFailed
    }
    
    private let transformer = LocalDocumentTransformer()
    
    /// Extracts steps from a PDF document using a local Document Understanding Transformer (Donut).
    func extractSteps(from document: PDFDocument) async throws -> [AssemblyStep] {
        guard document.pageCount > 0 else { throw ExtractionError.emptyDocument }
        
        var steps: [AssemblyStep] = []
        let pageLimit = min(document.pageCount, 10)
        
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
            
            // 1. Pass the image to our local Transformer model
            if var extractedStep = try? await transformer.processPage(cgImage: cgImage) {
                // 2. Attach the raw image data so the user can view the diagram on their phone
                extractedStep.imageData = img.jpegData(compressionQuality: 0.8)
                steps.append(extractedStep)
            }
        }
        
        if steps.isEmpty && document.pageCount > 0 {
            steps.append(AssemblyStep(id: 1, instruction: "Begin assembly by following the PDF.", imageName: "doc.text", audioPrompt: "Let's begin assembly.", requiredParts: []))
        }
        
        return steps
    }
}
