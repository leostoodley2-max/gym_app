import SwiftUI

struct VerificationBadge: View {
    let status: VerificationStatus
    var showsLabel = true

    var body: some View {
        if showsLabel {
            // HStack rather than Label: inside List rows, Label gets list icon spacing.
            HStack(spacing: 4) {
                Image(systemName: status.symbol)
                Text(status.displayName)
            }
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(status.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(status.color.opacity(0.14), in: Capsule())
            .accessibilityElement(children: .combine)
        } else {
            Image(systemName: status.symbol)
                .font(.caption)
                .foregroundStyle(status.color)
                .accessibilityLabel(status.displayName)
        }
    }
}

struct TierBadge: View {
    let tier: StrengthTier
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.symbol)
            if !compact { Text(tier.displayName.uppercased()) }
        }
        .font(.caption2.weight(.heavy))
        .foregroundStyle(tier.color)
        .padding(.horizontal, compact ? 6 : 9)
        .padding(.vertical, 4)
        .background(tier.color.opacity(0.15), in: Capsule())
        .accessibilityLabel("\(tier.displayName) tier")
    }
}

struct PRBadge: View {
    var body: some View {
        Text("PR")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.accent, in: Capsule())
            .accessibilityLabel("Personal record")
    }
}

struct ProBadge: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "crown.fill")
            Text("PRO")
        }
        .font(.system(size: 9, weight: .black))
        .foregroundStyle(Theme.onAccent)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(Theme.accent, in: Capsule())
        .accessibilityLabel("Pro member")
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var colors: (Color, Color) {
        let palette: [(Color, Color)] = [
            (Theme.accent, Theme.teal), (Theme.lavender, Theme.pink), (Theme.teal, Theme.lavender),
            (Theme.orange, Theme.pink), (Theme.pink, Theme.lavender), (Theme.accent, Theme.orange),
        ]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.38, weight: .black, design: .rounded))
            .foregroundStyle(Theme.onAccent)
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [colors.0, colors.1], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: Circle())
            .accessibilityHidden(true)
    }
}

/// Stat tile with a progress ring around its icon, as in the reference designs.
struct RingStatTile: View {
    let symbol: String
    let value: String
    let label: String
    var progress: Double = 0
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.08), lineWidth: 3.5)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().fill(Theme.surfaceRaised).padding(6)
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.stat(20))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 22)
        .accessibilityElement(children: .combine)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.stat(22))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 14, radius: 22)
        .accessibilityElement(children: .combine)
    }
}

struct RankMedal: View {
    let rank: Int

    private var color: Color? {
        switch rank {
        case 1: return Theme.accent
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return nil
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.stat(15, weight: .heavy).monospacedDigit())
            .foregroundStyle(color == nil ? Theme.secondaryText : Theme.onAccent)
            .frame(minWidth: 30, minHeight: 30)
            .background {
                if let color { Circle().fill(color) }
            }
            .accessibilityLabel("Rank \(rank)")
    }
}

/// Small "pin + gym name" caption for profile headers.
struct GymCaption: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.accent)
            Text(name).foregroundStyle(Theme.secondaryText)
        }
        .font(.caption)
    }
}
