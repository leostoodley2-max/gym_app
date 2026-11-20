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
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.12), in: Capsule())
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
            if !compact { Text(tier.displayName) }
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tier.color)
        .padding(.horizontal, compact ? 5 : 8)
        .padding(.vertical, 3)
        .background(tier.color.opacity(0.15), in: Capsule())
        .accessibilityLabel("\(tier.displayName) tier")
    }
}

struct PRBadge: View {
    var body: some View {
        Text("PR")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.gold, in: Capsule())
            .accessibilityLabel("Personal record")
    }
}

struct AvatarView: View {
    let name: String
    var size: CGFloat = 36

    private var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    private var color: Color {
        let palette: [Color] = [.red, .orange, .green, .teal, .blue, .indigo, .purple, .pink, .brown]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .accessibilityHidden(true)
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

struct RankMedal: View {
    let rank: Int

    private var color: Color? {
        switch rank {
        case 1: return Theme.gold
        case 2: return Theme.silver
        case 3: return Theme.bronze
        default: return nil
        }
    }

    var body: some View {
        Text("\(rank)")
            .font(.subheadline.weight(.heavy).monospacedDigit())
            .foregroundStyle(color == nil ? Color.secondary : Color.white)
            .frame(minWidth: 30, minHeight: 30)
            .background {
                if let color { Circle().fill(color) }
            }
            .accessibilityLabel("Rank \(rank)")
    }
}

/// Small "pin + gym name" caption for profile headers inside lists.
struct GymCaption: View {
    let name: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.and.ellipse").foregroundStyle(Theme.accent)
            Text(name)
        }
        .font(.caption)
    }
}
