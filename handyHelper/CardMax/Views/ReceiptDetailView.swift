import SwiftUI

struct ReceiptDetailView: View {
    @Binding var receipt: Receipt
    let userCards: [CreditCard]
    let onDelete: () -> Void
    let onUpdate: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showCategoryPicker = false
    @State private var showMerchantEdit = false
    @State private var editedMerchantName = ""

    private let textPrimary = Color(hex: "1A1A1A")
    private let textSecondary = Color(hex: "6A6A6A")

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Receipt image
                    if let image = receipt.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    }

                    // Annotation card
                    annotationCard

                    // Metadata
                    HStack {
                        Label {
                            Text(receipt.capturedAt, style: .date)
                        } icon: {
                            Image(systemName: "calendar")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(textSecondary)

                        Spacer()

                        Label {
                            Text(receipt.capturedAt, style: .time)
                        } icon: {
                            Image(systemName: "clock")
                        }
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(textSecondary)
                    }
                }
                .padding(20)
            }
            .background(Color(hex: "F5F3F0").ignoresSafeArea())
            .navigationTitle("Receipt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategoryPickerView(
                    selectedCategory: receipt.category,
                    onSelect: { category in
                        receipt.category = category
                        if let best = bestCardForCategory(category) {
                            receipt.recommendedCard = best
                        }
                        onUpdate()
                    }
                )
            }
            .alert("Merchant Name", isPresented: $showMerchantEdit) {
                TextField("Merchant name", text: $editedMerchantName)
                Button("Save") {
                    let name = editedMerchantName.trimmingCharacters(in: .whitespaces)
                    receipt.merchantName = name.isEmpty ? nil : name
                    // Try to auto-detect category from merchant name
                    if let name = receipt.merchantName, let merchant = Merchant.findByKeyword(name) {
                        receipt.category = merchant.primaryCategory
                        if let best = bestCardForCategory(merchant.primaryCategory) {
                            receipt.recommendedCard = best
                        }
                    }
                    onUpdate()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter the merchant name from the receipt.")
            }
        }
    }

    private var annotationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECEIPT DETAILS")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(textSecondary)

            VStack(spacing: 0) {
                // Merchant — tappable to edit
                Button {
                    editedMerchantName = receipt.merchantName ?? ""
                    showMerchantEdit = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "storefront")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)
                            .frame(width: 24)

                        Text("Merchant")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(textSecondary)

                        Spacer()

                        Text(receipt.merchantName ?? "Tap to set")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(receipt.merchantName != nil ? textPrimary : Color(hex: "FF6B2B"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Divider().padding(.horizontal, 12)

                // Category — tappable to change
                Button {
                    showCategoryPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: receipt.category?.icon ?? "tag")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(textSecondary)
                            .frame(width: 24)

                        Text("Category")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(textSecondary)

                        Spacer()

                        Text(receipt.category?.displayName ?? "Tap to set")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(receipt.category != nil ? textPrimary : Color(hex: "FF6B2B"))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider().padding(.horizontal, 12)

                if let card = receipt.recommendedCard {
                    annotationRow(icon: "creditcard", label: "Best Card", value: card)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private func annotationRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(textSecondary)
                .frame(width: 24)

            Text(label)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func bestCardForCategory(_ category: MerchantCategory) -> String? {
        var bestRate: Float = 0
        var bestCard: CreditCard?

        for card in userCards where card.isActive {
            let effective = card.effectiveCategoryRewards
            let rate = effective[category] ?? card.defaultRate
            if rate > bestRate {
                bestRate = rate
                bestCard = card
            }
        }

        guard let card = bestCard else { return nil }
        return card.owner == "Me" ? card.nickname : "\(card.owner)'s \(card.nickname)"
    }
}

// MARK: - Category Picker

struct CategoryPickerView: View {
    let selectedCategory: MerchantCategory?
    let onSelect: (MerchantCategory) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(MerchantCategory.allCases, id: \.self) { category in
                        Button {
                            onSelect(category)
                            dismiss()
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "6A6A6A"))
                                    .frame(width: 28)

                                Text(category.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color(hex: "1A1A1A"))

                                Spacer()

                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(hex: "FF6B2B"))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }

                        if category != MerchantCategory.allCases.last {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(Color.white)
                .cornerRadius(14)
                .padding(16)
            }
            .background(Color(hex: "F5F3F0").ignoresSafeArea())
            .navigationTitle("Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
        }
    }
}
