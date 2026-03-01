import SwiftUI
import PDFKit

struct ManualHubView: View {
    @StateObject private var manager = ManualManager()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            List {
                Section("Search Products") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search by name or IKEA ID", text: $searchText)
                            .onChange(of: searchText) { newValue in
                                manager.search(query: newValue)
                            }
                    }
                    
                    if !manager.searchResults.isEmpty {
                        ForEach(manager.searchResults) { manual in
                            NavigationLink(destination: ManualDetailView(manual: manual, manager: manager)) {
                                HStack {
                                    Image(systemName: manual.thumbnailImageName ?? "doc.fill")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text(manual.productName).font(.headline)
                                        Text(manual.id).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                
                if !manager.library.isEmpty {
                    Section("Saved Manuals") {
                        ForEach(manager.library) { manual in
                            NavigationLink(destination: ManualDetailView(manual: manual, manager: manager)) {
                                Label(manual.productName, systemImage: "books.vertical.fill")
                            }
                        }
                    }
                }
                
                if !manager.history.isEmpty {
                    Section("Assembly History") {
                        ForEach(manager.history) { record in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(record.productName).font(.subheadline)
                                    Text(record.completedDate, style: .date).font(.caption2).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Handy Library")
        }
    }
}

struct ManualDetailView: View {
    @State var manual: FurnitureManual
    @ObservedObject var manager: ManualManager
    @State private var showingAssembly = false
    @State private var isExtracting = false
    @Environment(\.dismiss) var dismiss
    
    var pdfDocument: PDFDocument? {
        guard let assetName = manual.pdfAssetName,
              let dataAsset = NSDataAsset(name: assetName),
              let document = PDFDocument(data: dataAsset.data) else {
            return nil
        }
        return document
    }
    
    var body: some View {
        VStack {
            if let document = pdfDocument {
                PDFKitView(document: document)
                    .cornerRadius(12)
                    .padding()
            } else {
                // PDF Placeholder
                ZStack {
                    Color.gray.opacity(0.1)
                    VStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        Text("Instruction Manual")
                            .font(.headline)
                        Text(manual.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .cornerRadius(12)
                .padding()
            }
            
            VStack(spacing: 15) {
                if isExtracting {
                    ProgressView("Extracting steps with AI Vision...")
                        .padding()
                } else {
                    Button(action: {
                        startAssembly()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Guided Assembly")
                        }
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Button(action: {
                    manager.completeAssembly(for: manual)
                    dismiss()
                }) {
                    Text("Quick Mark as Assembled")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .navigationTitle(manual.productName)
        .fullScreenCover(isPresented: $showingAssembly) {
            NavigationStack {
                AssemblySessionView(manual: manual, manager: manager)
            }
        }
        .onAppear {
            manager.addToLibrary(manual)
        }
    }
    
    private func startAssembly() {
        if manual.steps.isEmpty, let document = pdfDocument {
            isExtracting = true
            Task {
                do {
                    let extractor = InstructionExtractionService()
                    let extractedSteps = try await extractor.extractSteps(from: document)
                    
                    await MainActor.run {
                        self.manual.steps = extractedSteps
                        self.isExtracting = false
                        self.showingAssembly = true
                    }
                } catch {
                    await MainActor.run {
                        self.isExtracting = false
                        print("Failed to extract steps: \(error)")
                        // Even if extraction fails, start with empty steps or mock
                        self.showingAssembly = true
                    }
                }
            }
        } else {
            showingAssembly = true
        }
    }
}
