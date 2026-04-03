import Foundation

struct ReceiptStorageService {
    private static let fileName = "cardmax_receipts.json"

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func save(_ receipts: [Receipt]) {
        do {
            let data = try JSONEncoder().encode(receipts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("CardMax: Failed to save receipts - \(error.localizedDescription)")
        }
    }

    static func load() -> [Receipt] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([Receipt].self, from: data)
        } catch {
            print("CardMax: Failed to load receipts - \(error.localizedDescription)")
            return []
        }
    }

    static func deleteImage(_ fileName: String) {
        let url = Receipt.imageDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }
}
