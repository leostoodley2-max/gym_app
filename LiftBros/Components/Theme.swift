import SwiftUI

enum Theme {
    static let accent = Color("AccentColor")
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let gold = Color(red: 0.98, green: 0.76, blue: 0.18)
    static let silver = Color(red: 0.70, green: 0.73, blue: 0.77)
    static let bronze = Color(red: 0.78, green: 0.50, blue: 0.27)
}

extension StrengthTier {
    var color: Color {
        switch self {
        case .bronze: return Theme.bronze
        case .silver: return Theme.silver
        case .gold: return Theme.gold
        case .platinum: return Color(red: 0.35, green: 0.80, blue: 0.75)
        case .diamond: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .elite: return Color(red: 0.72, green: 0.36, blue: 0.98)
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
        case .verified: return .green
        case .pending: return .orange
        case .unverified: return .secondary
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

    static func volume(_ kg: Double, _ unit: WeightUnit) -> String {
        let value = unit.fromKg(kg)
        if value >= 1000 {
            return "\((value / 1000).formatted(.number.precision(.fractionLength(1))))k \(unit.symbol)"
        }
        return "\(Int(value)) \(unit.symbol)"
    }
}
