import Foundation

public enum StrengthTier: Int, CaseIterable, Comparable, Codable, Hashable, Sendable {
    case bronze, silver, gold, platinum, diamond, elite

    public static func < (lhs: StrengthTier, rhs: StrengthTier) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        case .diamond: return "Diamond"
        case .elite: return "Elite"
        }
    }

    public var next: StrengthTier? { StrengthTier(rawValue: rawValue + 1) }
}

public enum StrengthCalculator {
    /// Sets above this rep count are too unreliable to estimate a 1RM, so they don't rank.
    public static let maxRankableReps = 12

    /// Estimated one-rep max using the Epley formula below 10 reps and Brzycki from 10 reps.
    /// A single rep returns the load itself.
    public static func estimatedOneRepMax(load: Double, reps: Int) -> Double {
        guard reps > 0, load > 0 else { return 0 }
        if reps == 1 { return load }
        if reps < 10 {
            return load * (1 + Double(reps) / 30)
        }
        let cappedReps = min(reps, 36)
        return load * 36 / (37 - Double(cappedReps))
    }

    /// The load actually moved: adds bodyweight for weighted pull-ups/dips.
    public static func effectiveLoad(weightKg: Double, bodyweightKg: Double, exercise: Exercise?) -> Double {
        guard let exercise, exercise.addsBodyweight else { return weightKg }
        return weightKg + bodyweightKg
    }

    public static func estimatedOneRepMax(for set: LiftSet, exercise: Exercise?) -> Double {
        estimatedOneRepMax(load: effectiveLoad(weightKg: set.weightKg, bodyweightKg: set.bodyweightKg, exercise: exercise),
                           reps: set.reps)
    }

    public static func estimatedOneRepMax(for record: LiftRecord) -> Double {
        let exercise = ExerciseLibrary.exercise(id: record.exerciseID)
        return estimatedOneRepMax(load: effectiveLoad(weightKg: record.weightKg, bodyweightKg: record.bodyweightKg,
                                                      exercise: exercise),
                                  reps: record.reps)
    }

    public static func relativeStrength(oneRepMaxKg: Double, bodyweightKg: Double) -> Double {
        guard bodyweightKg > 0 else { return 0 }
        return oneRepMaxKg / bodyweightKg
    }

    public static func isRankable(reps: Int) -> Bool { (1...maxRankableReps).contains(reps) }

    public static func tier(ratio: Double, exercise: Exercise, sex: Sex) -> StrengthTier {
        let thresholds = exercise.standards.thresholds(for: sex)
        var tier = StrengthTier.bronze
        for (index, threshold) in thresholds.enumerated() where ratio >= threshold {
            tier = StrengthTier(rawValue: index + 1) ?? .elite
        }
        return tier
    }

    public static func tier(oneRepMaxKg: Double, bodyweightKg: Double, exercise: Exercise, sex: Sex) -> StrengthTier {
        tier(ratio: relativeStrength(oneRepMaxKg: oneRepMaxKg, bodyweightKg: bodyweightKg), exercise: exercise, sex: sex)
    }

    /// The estimated 1RM needed to reach the next tier, or nil at Elite.
    public static func oneRepMaxForNextTier(currentTier: StrengthTier, bodyweightKg: Double, exercise: Exercise,
                                            sex: Sex) -> Double? {
        guard let next = currentTier.next else { return nil }
        let thresholds = exercise.standards.thresholds(for: sex)
        return thresholds[next.rawValue - 1] * bodyweightKg
    }

    /// Working weight for a target rep count given a 1RM (inverse Epley/Brzycki).
    public static func weightFor(reps: Int, oneRepMaxKg: Double) -> Double {
        guard reps > 0 else { return 0 }
        if reps == 1 { return oneRepMaxKg }
        if reps < 10 { return oneRepMaxKg / (1 + Double(reps) / 30) }
        return oneRepMaxKg * (37 - Double(min(reps, 36))) / 36
    }
}
