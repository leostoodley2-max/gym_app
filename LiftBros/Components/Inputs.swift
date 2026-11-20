import SwiftUI

/// A labelled decimal text field bound to an optional number. Empty text means nil.
struct DecimalField: View {
    let title: String
    @Binding var value: Double?
    var suffix: String?
    var prompt = "—"

    @State private var text = ""
    @State private var didLoad = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(prompt, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 110)
                .onChange(of: text) { _, newValue in
                    value = Double(newValue.replacingOccurrences(of: ",", with: "."))
                }
            if let suffix {
                Text(suffix).foregroundStyle(.secondary)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            if let value { text = DecimalField.format(value) }
        }
    }

    static func format(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}

/// Large +/− weight entry used when logging sets.
struct WeightStepper: View {
    @Binding var weight: Double
    let step: Double
    let unit: WeightUnit
    let label: String

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 16) {
            stepButton(systemImage: "minus") { weight = max(0, weight - step) }
            VStack(spacing: 2) {
                TextField("0", text: $text)
                    .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focused)
                    .onChange(of: text) { _, newValue in
                        if let parsed = Double(newValue.replacingOccurrences(of: ",", with: ".")) { weight = parsed }
                    }
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            stepButton(systemImage: "plus") { weight += step }
        }
        .onAppear { text = DecimalField.format(weight) }
        .onChange(of: weight) { _, newValue in
            if !focused { text = DecimalField.format(newValue) }
        }
    }

    private func stepButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .frame(width: 52, height: 52)
                .background(Theme.accent.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
    }
}
