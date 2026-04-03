import Foundation

struct AssemblyStep: Identifiable, Codable, Hashable {
    let id: Int
    let instruction: String
    let imageName: String? // Name of an asset or a symbol
    var imageData: Data? = nil // Raw extracted image from PDF
    let audioPrompt: String
    var requiredParts: [String] = [] // e.g. ["dowel", "screw_1104"]
}

struct FurnitureManual: Identifiable, Codable, Hashable {
    let id: String
    let productName: String
    let category: String
    let pdfURL: URL?
    let pdfAssetName: String?
    let thumbnailImageName: String?
    var steps: [AssemblyStep]
    
    // Mock data helper
    static let mockData = [
        FurnitureManual(
            id: "101.352.21", 
            productName: "LACK Side Table", 
            category: "Tables", 
            pdfURL: nil, 
            pdfAssetName: nil,
            thumbnailImageName: "table.fill",
            steps: [
                AssemblyStep(id: 1, instruction: "Place the table top face down on a soft surface.", imageName: "square.and.arrow.down", audioPrompt: "Place the table top face down on a rug or soft surface."),
                AssemblyStep(id: 2, instruction: "Screw the four legs into the corners.", imageName: "plus.circle", audioPrompt: "Now, take the four legs and screw them into the holes at each corner."),
                AssemblyStep(id: 3, instruction: "Turn the table over. You're done!", imageName: "checkmark.circle", audioPrompt: "Great job! Turn the table over. You are all finished.")
            ]
        ),
        FurnitureManual(id: "202.123.45", productName: "BILLY Bookcase", category: "Storage", pdfURL: nil, pdfAssetName: nil, thumbnailImageName: "books.vertical.fill", steps: []),
        FurnitureManual(id: "303.987.65", productName: "MALM Bed Frame", category: "Beds", pdfURL: nil, pdfAssetName: "malm_manual", thumbnailImageName: "bed.double.fill", steps: []),
        FurnitureManual(id: "404.555.12", productName: "PAX Wardrobe Frame", category: "Storage", pdfURL: nil, pdfAssetName: "pax_manual", thumbnailImageName: "cabinet.fill", steps: [])
    ]
}

struct AssemblyHistory: Identifiable, Codable {
    let id: UUID
    let manualID: String
    let productName: String
    let completedDate: Date
}
