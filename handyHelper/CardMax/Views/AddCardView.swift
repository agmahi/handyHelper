import SwiftUI

struct AddCardView: View {
    @ObservedObject var viewModel: CardMaxViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var cardToAdd: CreditCard?
    @State private var ownerName = ""
    @State private var selectedColor: CardColor = .blue

    /// Known owners from existing cards, for quick selection
    private var knownOwners: [String] {
        let owners = Set(viewModel.userCards.map(\.owner))
        return Array(owners).sorted()
    }

    /// Cards from catalog — allow duplicates for different owners
    private var availableCards: [CreditCard] {
        let filtered = CreditCard.catalog
        if searchText.isEmpty { return filtered }
        let query = searchText.lowercased()
        return filtered.filter {
            $0.fullName.lowercased().contains(query) ||
            $0.issuer.displayName.lowercased().contains(query) ||
            $0.nickname.lowercased().contains(query)
        }
    }

    /// Group available cards by issuer
    private var groupedCards: [(issuer: String, cards: [CreditCard])] {
        let grouped = Dictionary(grouping: availableCards) { $0.issuer.displayName }
        return grouped.sorted { $0.key < $1.key }.map { (issuer: $0.key, cards: $0.value) }
    }

    /// Pick a color that doesn't duplicate the last card in the wallet
    private func autoPickColor(for card: CreditCard) -> CardColor {
        let usedColors = Set(viewModel.userCards.suffix(2).map(\.color))
        // Try the card's default color first
        if !usedColors.contains(card.color) { return card.color }
        // Otherwise pick the first unused color
        return CardColor.allCases.first { !usedColors.contains($0) } ?? card.color
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "F5F3F0").ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 24) {
                        ForEach(groupedCards, id: \.issuer) { group in
                            issuerSection(group.issuer, cards: group.cards)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .searchable(text: $searchText, prompt: "Search cards")
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
            .alert("Whose card is this?", isPresented: Binding(
                get: { cardToAdd != nil },
                set: { if !$0 { cardToAdd = nil; ownerName = "" } }
            )) {
                TextField("Name", text: $ownerName)
                Button("Add") {
                    if let card = cardToAdd {
                        let name = ownerName.trimmingCharacters(in: .whitespaces)
                        let owner = name.isEmpty ? "Me" : name
                        let newCard = CreditCard(
                            nickname: card.nickname,
                            fullName: card.fullName,
                            issuer: card.issuer,
                            network: card.network,
                            lastFourDigits: card.lastFourDigits,
                            defaultRate: card.defaultRate,
                            categoryRewards: card.categoryRewards,
                            merchantBonuses: card.merchantBonuses,
                            rotatingCategories: card.rotatingCategories,
                            owner: owner,
                            annualFee: card.annualFee,
                            color: selectedColor
                        )
                        viewModel.addCard(newCard)
                    }
                    cardToAdd = nil
                    ownerName = ""
                }
                Button("Cancel", role: .cancel) {
                    cardToAdd = nil
                    ownerName = ""
                }
            } message: {
                if knownOwners.count > 1 {
                    Text("Enter a name, or leave blank for \"Me\". Existing: \(knownOwners.joined(separator: ", "))")
                } else {
                    Text("Enter a name, or leave blank for \"Me\".")
                }
            }
        }
    }

    private func issuerSection(_ issuer: String, cards: [CreditCard]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(issuer.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(hex: "8A8A8A"))

            VStack(spacing: 0) {
                ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                    if index > 0 {
                        Divider().padding(.leading, 68)
                    }
                    cardRow(card)
                }
            }
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private func cardRow(_ card: CreditCard) -> some View {
        Button {
            ownerName = ""
            selectedColor = autoPickColor(for: card)
            cardToAdd = card
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: card.color.hexValue))
                    .frame(width: 44, height: 30)
                    .overlay(
                        Text(card.network.displayName.prefix(1))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.fullName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "1A1A1A"))

                    Text(rewardSummary(card))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "8A8A8A"))
                }

                Spacer()

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(Color(hex: "FF6B2B"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func rewardSummary(_ card: CreditCard) -> String {
        let top = card.effectiveCategoryRewards
            .sorted { $0.value > $1.value }
            .prefix(2)
            .map { "\(Int($0.value))% \($0.key.displayName)" }

        if top.isEmpty {
            return "\(Int(card.defaultRate))% on everything"
        }
        return top.joined(separator: ", ")
    }
}
