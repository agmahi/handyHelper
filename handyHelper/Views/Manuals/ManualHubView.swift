import SwiftUI
import PDFKit
import MWDATCore

struct ManualHubView: View {
    let wearables: WearablesInterface
    @ObservedObject var wearablesVM: WearablesViewModel
    
    @StateObject private var manager = ManualManager()
    @State private var searchText = ""
    
    var body: some View {
        List {
            Section("My Glasses") {
                HStack {
                    Image(systemName: "sunglasses.fill")
                        .foregroundColor(wearablesVM.registrationState == .registered ? .green : .orange)
                    
                    VStack(alignment: .leading) {
                        Text(wearablesVM.registrationState == .registered ? "Glasses Connected" : "Glasses Not Linked")
                            .font(.subheadline).bold()
                        Text(wearablesVM.registrationState == .registered ? "POV Vision Enabled" : "Tap to link with Meta AI")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if wearablesVM.registrationState != .registered {
                        Button("Link") {
                            wearablesVM.connectGlasses()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
            
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
                            NavigationLink(destination: ManualDetailView(manual: manual, manager: manager, wearables: wearables, wearablesVM: wearablesVM)) {
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
                            NavigationLink(destination: ManualDetailView(manual: manual, manager: manager, wearables: wearables, wearablesVM: wearablesVM)) {
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

struct ManualDetailView: View {
    @StateObject var detailVM: ManualDetailViewModel
    @ObservedObject var wearablesVM: WearablesViewModel
    @Environment(\.dismiss) var dismiss
    
    init(manual: FurnitureManual, manager: ManualManager, wearables: WearablesInterface, wearablesVM: WearablesViewModel) {
        _detailVM = StateObject(wrappedValue: ManualDetailViewModel(manual: manual, manager: manager, wearables: wearables))
        self.wearablesVM = wearablesVM
    }
    
    var body: some View {
        VStack {
            if let document = detailVM.pdfDocument {
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
                        Text(detailVM.manual.id)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .cornerRadius(12)
                .padding()
            }
            
            VStack(spacing: 15) {
                if detailVM.isExtracting {
                    ProgressView("Extracting steps with AI Vision...")
                        .padding()
                } else {
                    Button(action: {
                        detailVM.startAssembly()
                    }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text(wearablesVM.registrationState == .registered ? "Start Guided Assembly" : "Start Manual Assembly")
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
                    detailVM.manager.completeAssembly(for: detailVM.manual)
                    dismiss()
                }) {
                    Text("Quick Mark as Assembled")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
            }
            .padding()
        }
        .navigationTitle(detailVM.manual.productName)
        .fullScreenCover(isPresented: $detailVM.showingAssembly) {
            NavigationStack {
                AssemblySessionView(viewModel: AssemblyViewModel(manual: detailVM.manual, manager: detailVM.manager, wearables: detailVM.wearables, onDismiss: {
                    detailVM.showingAssembly = false
                }))
            }
        }
        .onAppear {
            detailVM.manager.addToLibrary(detailVM.manual)
        }
    }
}
