import Foundation
import SwiftUI
import PDFKit
import Combine
import MWDATCore

@MainActor
class ManualDetailViewModel: ObservableObject {
    @Published var manual: FurnitureManual
    @Published var isExtracting = false
    @Published var showingAssembly = false
    
    let wearables: WearablesInterface
    let manager: ManualManager
    
    init(manual: FurnitureManual, manager: ManualManager, wearables: WearablesInterface) {
        self.manual = manual
        self.manager = manager
        self.wearables = wearables
    }
    
    var pdfDocument: PDFDocument? {
        guard let assetName = manual.pdfAssetName,
              let dataAsset = NSDataAsset(name: assetName),
              let document = PDFDocument(data: dataAsset.data) else {
            return nil
        }
        return document
    }
    
    func startAssembly() {
        if manual.steps.isEmpty, let document = pdfDocument {
            isExtracting = true
            Task {
                do {
                    let extractor = InstructionExtractionService()
                    let extractedSteps = try await extractor.extractSteps(from: document)
                    
                    self.manual.steps = extractedSteps
                    self.isExtracting = false
                    self.showingAssembly = true
                } catch {
                    self.isExtracting = false
                    print("Failed to extract steps: \(error)")
                    // For MVP, even if extraction fails, enter session so UI is tested
                    self.showingAssembly = true
                }
            }
        } else {
            showingAssembly = true
        }
    }
}
