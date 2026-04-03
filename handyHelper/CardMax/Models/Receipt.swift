import Foundation
import UIKit

struct Receipt: Codable, Identifiable {
    let id: UUID
    let imageFileName: String
    let capturedAt: Date

    // OCR-extracted annotation (populated after capture)
    var merchantName: String?
    var category: MerchantCategory?
    var recommendedCard: String?     // Card nickname, e.g. "Amex Gold"

    init(id: UUID = UUID(), image: UIImage) {
        self.id = id
        self.capturedAt = Date()
        self.imageFileName = "\(id.uuidString).jpg"

        // Save image to documents
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: Self.imageDirectory.appendingPathComponent(imageFileName))
        }
    }

    var image: UIImage? {
        let url = Self.imageDirectory.appendingPathComponent(imageFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    var hasAnnotation: Bool {
        merchantName != nil || category != nil
    }

    static var imageDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("receipts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
