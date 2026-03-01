import Foundation
import Combine

class ManualManager: ObservableObject {
    @Published var searchResults: [FurnitureManual] = []
    @Published var library: [FurnitureManual] = []
    @Published var history: [AssemblyHistory] = []
    
    private let historyKey = "handyhelper.assembly.history"
    private let libraryKey = "handyhelper.manual.library"
    
    init() {
        loadHistory()
        loadLibrary()
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // MVP: Simple local filtering
        searchResults = FurnitureManual.mockData.filter { 
            $0.productName.lowercased().contains(query.lowercased()) || 
            $0.id.contains(query)
        }
    }
    
    func addToLibrary(_ manual: FurnitureManual) {
        if !library.contains(where: { $0.id == manual.id }) {
            library.append(manual)
            saveLibrary()
        }
    }
    
    func completeAssembly(for manual: FurnitureManual) {
        let newEntry = AssemblyHistory(id: UUID(), manualID: manual.id, productName: manual.productName, completedDate: Date())
        history.insert(newEntry, at: 0)
        saveHistory()
    }
    
    // MARK: - Persistence
    private func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([AssemblyHistory].self, from: data) {
            history = decoded
        }
    }
    
    private func saveLibrary() {
        if let encoded = try? JSONEncoder().encode(library) {
            UserDefaults.standard.set(encoded, forKey: libraryKey)
        }
    }
    
    private func loadLibrary() {
        if let data = UserDefaults.standard.data(forKey: libraryKey),
           let decoded = try? JSONDecoder().decode([FurnitureManual].self, from: data) {
            library = decoded
        }
    }
}
