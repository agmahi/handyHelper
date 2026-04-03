import Foundation
import PDFKit
import CoreImage

class InstructionExtractionService {
    
    enum ExtractionError: Error {
        case emptyDocument
        case processingFailed
    }
    
    /// EXTRACT FROM OFFLINE GPT-4o JSON
    /// We use the clean JSON generated offline to populate our instruction steps.
    func extractStepsFromJSON(_ data: Data) throws -> [AssemblyStep] {
        let decoder = JSONDecoder()
        do {
            let steps = try decoder.decode([AssemblyStep].self, from: data)
            return steps
        } catch {
            print("InstructionExtractionService: Failed to decode JSON - \(error)")
            throw ExtractionError.processingFailed
        }
    }

    /// Meta Ray-Ban Camera Stream Logic
    func extractSteps(from document: PDFDocument) async throws -> [AssemblyStep] {
        // Simulate network/processing latency
        try await Task.sleep(nanoseconds: 1_500_000_000)
        
        let mockSteps = [
            AssemblyStep(
                id: 1, 
                instruction: "Step 1: Find the main side panel.\n(Testing: Look at a 'cell phone' to simulate finding the panel)", 
                imageName: "rectangle.portrait.fill", 
                audioPrompt: "Let's begin. First, find the main side panel. For this test, look at a cell phone.", 
                requiredParts: ["cell phone"]
            ),
            AssemblyStep(
                id: 2, 
                instruction: "Step 2: Grab two wooden dowels.\n(Testing: Look at a 'cup' to simulate finding the dowels)", 
                imageName: "cylinder.fill", 
                audioPrompt: "Great. Now grab two wooden dowels. For this test, look at a cup.", 
                requiredParts: ["cup"]
            ),
            AssemblyStep(
                id: 3, 
                instruction: "Step 3: Insert the cam lock screws.\n(Testing: Look at a 'keyboard' to simulate the screws)", 
                imageName: "screw.fill", 
                audioPrompt: "Perfect. Next, locate the cam lock screws. For this test, look at a keyboard.", 
                requiredParts: ["keyboard"]
            ),
            AssemblyStep(
                id: 4, 
                instruction: "Step 4: Attach the base.\n(Testing: Look at a 'mouse' or 'bottle' to simulate the base)", 
                imageName: "rectangle.bottomthird.inset.filled", 
                audioPrompt: "Almost done. Attach the base panel. For this test, look at a computer mouse or a bottle.", 
                requiredParts: ["mouse", "bottle"]
            )
        ]
        
        return mockSteps
    }
}
