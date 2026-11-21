import SwiftUI

/// Capsule segmented control: selected option is a white pill with dark text.
struct PillPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { selection = option }
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule().fill(Color.white).matchedGeometryEffect(id: "pill", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke))
    }
}

/// Small rounded chip, e.g. for exercise filters.
struct Chip: View {
    let title: String
    var isSelected = false
    var systemImage: String?

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? Theme.onAccent : .white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isSelected ? Theme.accent : Theme.surface, in: Capsule())
        .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.stroke))
    }
}

/// Lime call-to-action button.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Theme.accent
    var foreground: Color = Theme.onAccent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(19))
            .textCase(.uppercase)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// Dark secondary button.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Round icon button used in headers.
struct CircleIconButton: View {
    let systemImage: String
    var tint: Color = .white
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(filled ? Theme.onAccent : tint)
                .frame(width: 44, height: 44)
                .background(filled ? Theme.accent : Theme.surface, in: Circle())
                .overlay(Circle().stroke(filled ? Color.clear : Theme.stroke))
        }
        .buttonStyle(.plain)
    }
}

/// Uppercase section title with an optional trailing action.
struct SectionHeader: View {
    let title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.display(22))
                .foregroundStyle(.white)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 3) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}

/// Screen title block used at the top of each tab.
struct ScreenTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let subtitle {
                Text(subtitle.uppercased())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            Text(title.uppercased())
                .font(.display(38))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Simple vertical bar chart with one highlighted bar (ref: weekly activity cards).
struct HighlightBarChart: View {
    struct Bar: Identifiable {
        let id: Int
        let label: String
        let value: Double
        let isHighlighted: Bool
    }

    let bars: [Bar]
    var height: CGFloat = 130
    var highlight: Color = Theme.accent

    var body: some View {
        let maxValue = max(bars.map(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(bars) { bar in
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(bar.isHighlighted ? highlight : Theme.surfaceRaised)
                        .frame(height: max(10, height * bar.value / maxValue))
                    Text(bar.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(bar.isHighlighted ? .white : Theme.secondaryText)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: height + 24, alignment: .bottom)
    }
}

/// Floating capsule tab bar (ref: pill-shaped bars with a highlighted selected item).
struct FloatingTabBar: View {
    @Binding var selection: AppTab

    private struct Item: Identifiable {
        let tab: AppTab
        let symbol: String
        let title: String
        var id: AppTab { tab }
    }

    private let items: [Item] = [
        Item(tab: .train, symbol: "dumbbell.fill", title: "Train"),
        Item(tab: .rankings, symbol: "trophy.fill", title: "Rankings"),
        Item(tab: .progress, symbol: "chart.bar.fill", title: "Progress"),
        Item(tab: .profile, symbol: "person.fill", title: "Profile"),
    ]

    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                let tab = item.tab
                let symbol = item.symbol
                let title = item.title
                let isSelected = selection == tab
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { selection = tab }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: symbol).font(.system(size: 17, weight: .bold))
                        if isSelected {
                            Text(title).font(.subheadline.weight(.bold)).lineLimit(1).fixedSize()
                        }
                    }
                    .foregroundStyle(isSelected ? Theme.onAccent : Theme.secondaryText)
                    .padding(.horizontal, isSelected ? 18 : 0)
                    .frame(maxWidth: isSelected ? nil : .infinity)
                    .frame(height: 50)
                    .background {
                        if isSelected {
                            Capsule().fill(Theme.accent).matchedGeometryEffect(id: "tab", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(Theme.surfaceRaised, in: Capsule())
        .overlay(Capsule().stroke(Theme.stroke))
        .shadow(color: .black.opacity(0.5), radius: 20, y: 8)
    }
}

/// Banner shown while the app runs on sample data (no live backend yet).
struct SampleDataBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(Theme.lavender)
            Text("Preview: gyms are real, lifters are sample data until LiftBros launches.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.lavender.opacity(0.10), padding: 12, radius: 14)
    }
}
