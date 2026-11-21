import SwiftUI

/// LiftBros design system: dark base, neon-lime accent, condensed display type, rounded cards.
enum Theme {
    static let accent = Color(red: 0.831, green: 1.0, blue: 0.247)            // #D4FF3F lime
    static let onAccent = Color(red: 0.05, green: 0.05, blue: 0.06)           // text on lime
    static let lavender = Color(red: 0.71, green: 0.64, blue: 1.0)            // #B5A3FF
    static let teal = Color(red: 0.18, green: 0.83, blue: 0.72)               // #2ED3B7
    static let pink = Color(red: 0.95, green: 0.72, blue: 0.93)               // #F2B8EE
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.27)              // #FF7A45

    static let background = Color(red: 0.043, green: 0.047, blue: 0.059)      // #0B0C0F
    static let surface = Color(red: 0.086, green: 0.094, blue: 0.11)          // #16181C
    static let surfaceRaised = Color(red: 0.125, green: 0.133, blue: 0.153)   // #202227
    static let stroke = Color.white.opacity(0.07)
    static let secondaryText = Color(red: 0.56, green: 0.58, blue: 0.61)

    static let cardBackground = surface
    static let gold = Color(red: 0.98, green: 0.80, blue: 0.25)
    static let silver = Color(red: 0.78, green: 0.80, blue: 0.84)
    static let bronze = Color(red: 0.84, green: 0.56, blue: 0.33)

    static let cornerRadius: CGFloat = 24
}

extension Font {
    /// Heavy, condensed display type for headlines (use with uppercase text).
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black).width(.condensed)
    }

    /// Rounded numerals for stats.
    static func stat(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension View {
    /// Standard dark card: padded content on a rounded surface.
    func card(_ color: Color = Theme.surface, padding: CGFloat = 16, radius: CGFloat = Theme.cornerRadius) -> some View {
        self.padding(padding)
            .background(color, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Dark screen background for scroll views.
    func screenBackground() -> some View {
        background(Theme.background.ignoresSafeArea())
    }

    /// Dark styling for List / Form based screens.
    func darkList() -> some View {
        scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
    }
}

extension StrengthTier {
    var color: Color {
        switch self {
        case .bronze: return Theme.bronze
        case .silver: return Theme.silver
        case .gold: return Theme.gold
        case .platinum: return Theme.teal
        case .diamond: return Theme.lavender
        case .elite: return Theme.accent
        }
    }

    var symbol: String {
        switch self {
        case .bronze, .silver, .gold: return "shield.fill"
        case .platinum: return "shield.lefthalf.filled"
        case .diamond: return "diamond.fill"
        case .elite: return "crown.fill"
        }
    }
}

extension VerificationStatus {
    var color: Color {
        switch self {
        case .verified: return Theme.teal
        case .pending: return Theme.orange
        case .unverified: return Theme.secondaryText
        case .rejected: return .red
        }
    }

    var symbol: String {
        switch self {
        case .verified: return "checkmark.seal.fill"
        case .pending: return "clock.badge.checkmark"
        case .unverified: return "seal"
        case .rejected: return "xmark.seal"
        }
    }
}

enum Format {
    static func weight(_ kg: Double, _ unit: WeightUnit, showUnit: Bool = true) -> String {
        let value = unit.fromKg(kg)
        let text = value.formatted(.number.precision(.fractionLength(0...1)))
        return showUnit ? "\(text) \(unit.symbol)" : text
    }

    static func ratio(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2))))× BW"
    }

    static func score(_ value: Double, metric: LeaderboardMetric, unit: WeightUnit) -> String {
        metric == .absolute ? weight(value, unit) : ratio(value)
    }

    static func liftSet(_ set: LiftSet, exercise: Exercise?, unit: WeightUnit) -> String {
        if exercise?.addsBodyweight == true {
            return "BW + \(weight(set.weightKg, unit)) × \(set.reps)"
        }
        return "\(weight(set.weightKg, unit)) × \(set.reps)"
    }

    static func record(_ record: LiftRecord, unit: WeightUnit) -> String {
        let exercise = ExerciseLibrary.exercise(id: record.exerciseID)
        if exercise?.addsBodyweight == true {
            return "BW + \(weight(record.weightKg, unit)) × \(record.reps)"
        }
        return "\(weight(record.weightKg, unit)) × \(record.reps)"
    }

    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }

    static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600, minutes = (total % 3600) / 60, seconds = total % 60
        return hours > 0
            ? String(format: "%ld:%02ld:%02ld", hours, minutes, seconds)
            : String(format: "%02ld:%02ld", minutes, seconds)
    }

    static func volume(_ kg: Double, _ unit: WeightUnit) -> String {
        let value = unit.fromKg(kg)
        if value >= 1000 {
            return "\((value / 1000).formatted(.number.precision(.fractionLength(1))))k \(unit.symbol)"
        }
        return "\(Int(value)) \(unit.symbol)"
    }
}
