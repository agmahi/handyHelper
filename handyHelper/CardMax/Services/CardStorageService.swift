import Foundation

/// Persists the user's credit card portfolio to disk as JSON.
struct CardStorageService {
    private static let fileName = "cardmax_cards.json"

    private static var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    static func save(_ cards: [CreditCard]) {
        do {
            let data = try JSONEncoder().encode(cards)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("CardMax: Failed to save cards - \(error.localizedDescription)")
        }
    }

    static func load() -> [CreditCard]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([CreditCard].self, from: data)
        } catch {
            print("CardMax: Failed to load cards - \(error.localizedDescription)")
            return nil
        }
    }
}
