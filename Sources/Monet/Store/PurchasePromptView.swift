import StoreKit
import SwiftUI

struct PurchasePromptView: View {
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool

    @State private var selectedProductID: StoreManager.ProductID = .lifetime

    private var selectedProduct: Product? {
        storeManager.product(for: selectedProductID)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {} // block clicks on background

            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Support iMonet")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Thank you for using iMonet to browse images! If you find it useful, please consider supporting us:")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Product Options
                VStack(spacing: 0) {
                    productOptionRow(.yearly)
                    Divider().padding(.leading, 36)
                    productOptionRow(.lifetime)
                }
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Buttons
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .frame(minWidth: 80)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.quaternary))

                    Button {
                        purchase()
                    } label: {
                        Group {
                            if storeManager.isPurchasing {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(buyButtonTitle)
                            }
                        }
                        .frame(minWidth: 80)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundColor(.white)
                    .disabled(storeManager.isPurchasing)
                }

                // Error
                if let error = storeManager.purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(28)
            .frame(width: 340)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(radius: 20)
        }
    }

    // MARK: - Product Option Row

    func productOptionRow(_ productID: StoreManager.ProductID) -> some View {
        let isSelected = selectedProductID == productID
        let product = storeManager.product(for: productID)

        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "circle.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(productID.displayName)
                        .fontWeight(.medium)
                    Text(productID.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let product {
                    Text(product.displayPrice)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var buyButtonTitle: String {
        if let product = selectedProduct {
            return String(localized: "Buy Now") + " (\(product.displayPrice))"
        }
        return String(localized: "Buy Now")
    }

    private func purchase() {
        guard let product = selectedProduct else { return }
        Task {
            await storeManager.purchase(product)
            if storeManager.isPurchased && storeManager.purchaseError == nil {
                dismiss()
            }
        }
    }

    private func dismiss() {
        UsageTracker.recordPrompt()
        isPresented = false
    }
}

// MARK: - ProductID Display Helpers

extension StoreManager.ProductID {
    var displayName: String {
        switch self {
        case .yearly: String(localized: "Yearly Support")
        case .lifetime: String(localized: "Lifetime Purchase")
        }
    }

    var description: String {
        switch self {
        case .yearly: String(localized: "¥6/year")
        case .lifetime: String(localized: "One-time purchase")
        }
    }
}
