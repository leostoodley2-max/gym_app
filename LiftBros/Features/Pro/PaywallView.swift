import SwiftUI

struct PaywallView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var selected: ProProduct = .yearly
    @State private var isPurchasing = false

    private var subscriptions: SubscriptionManager { store.subscriptions }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Spacer()
                    CircleIconButton(systemImage: "xmark") { dismiss() }
                        .accessibilityLabel("Close")
                }
                VStack(alignment: .leading, spacing: 8) {
                    ProBadge().scaleEffect(1.4, anchor: .leading)
                    Text("LIFT LIKE\nYOU MEAN IT")
                        .font(.display(54))
                        .foregroundStyle(.white)
                        .lineSpacing(-6)
                    Text("Everything in LiftBros stays free: logging, gym leaderboards and the national top 100. Pro adds the extras.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }

                VStack(spacing: 10) {
                    ForEach(ProFeature.allCases) { feature in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: feature.symbol)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 34, height: 34)
                                .background(Theme.accent, in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
                                Text(feature.detail).font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .card()

                if store.isPro {
                    Label("You're a Pro member. Thanks for supporting LiftBros!", systemImage: "checkmark.seal.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                    if subscriptions.previewPro {
                        Button("Turn off Pro preview") { subscriptions.setPreviewPro(false) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                } else {
                    HStack(spacing: 10) {
                        planOption(.yearly, badge: "SAVE 37%")
                        planOption(.monthly, badge: nil)
                    }
                    Button {
                        Task { await purchase() }
                    } label: {
                        if isPurchasing {
                            ProgressView().tint(Theme.onAccent)
                        } else {
                            Text("Start Pro")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isPurchasing)

                    if !subscriptions.storeAvailable && !subscriptions.isLoading {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("This is a test build, so the App Store isn't available. You can preview Pro features on this device.")
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryText)
                            Button("Preview Pro (testing only)") {
                                subscriptions.setPreviewPro(true)
                                dismiss()
                            }
                            .buttonStyle(SecondaryButtonStyle())
                        }
                    }
                    HStack {
                        Button("Restore purchases") { Task { await subscriptions.restore() } }
                        Spacer()
                        Text("Cancel anytime in Settings")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
                    if let error = subscriptions.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                    Text("Subscriptions renew automatically until cancelled. Payment is charged to your Apple ID. Prices include VAT.")
                        .font(.caption2)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(20)
        }
        .screenBackground()
    }

    private func planOption(_ product: ProProduct, badge: String?) -> some View {
        let isSelected = selected == product
        return Button {
            selected = product
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(product == .yearly ? "YEARLY" : "MONTHLY").font(.display(18))
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                }
                Text(subscriptions.displayPrice(product)).font(.stat(24))
                Text(product.periodLabel).font(.caption)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isSelected ? Theme.onAccent : Theme.accent, in: Capsule())
                        .foregroundStyle(isSelected ? Theme.accent : Theme.onAccent)
                }
            }
            .foregroundStyle(isSelected ? Theme.onAccent : .white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(isSelected ? Theme.accent : Theme.surface, padding: 14, radius: 20)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(isSelected ? Color.clear : Theme.stroke))
        }
        .buttonStyle(.plain)
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        if await subscriptions.purchase(selected) { dismiss() }
    }
}
