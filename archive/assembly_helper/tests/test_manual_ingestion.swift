import Foundation

// --- Mocking necessary project structures ---

struct AssemblyStep: Identifiable, Codable, Hashable {
    let id: Int
    let instruction: String
    let imageName: String?
    var imageData: Data? = nil
    let audioPrompt: String
    var requiredParts: [String] = []
}

class InstructionExtractionService {
    // Current implementation only has PDF extraction and it's mocked
    func extractStepsFromJSON(_ data: Data) throws -> [AssemblyStep] {
        let decoder = JSONDecoder()
        return try decoder.decode([AssemblyStep].self, from: data)
    }
}

// --- Test Case ---

let mockJSON = """
[
    {
        "id": 1,
        "instruction": "Step 1: Get the side panel.",
        "imageName": "panel_1",
        "audioPrompt": "Find the main side panel.",
        "requiredParts": ["panel_1"]
    },
    {
        "id": 2,
        "instruction": "Step 2: Attach the screw.",
        "imageName": "screw_2",
        "audioPrompt": "Attach the screw to the side panel.",
        "requiredParts": ["screw_2"]
    }
]
""".data(using: .utf8)!

let service = InstructionExtractionService()
do {
    let steps = try service.extractStepsFromJSON(mockJSON)
    if steps.count == 2 {
        print("Test Passed: Successfully parsed valid JSON.")
    } else {
        print("Test Failed: Expected 2 steps, got \(steps.count).")
        exit(1)
    }
} catch {
    print("Test Failed: Threw error \(error).")
    exit(1)
}
