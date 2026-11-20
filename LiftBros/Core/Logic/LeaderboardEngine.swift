import Foundation

public enum LeaderboardEngine {
    /// Unverified lifts flagged this many times are hidden until proof is provided.
    public static let flagHideThreshold = 3

    /// Ranks lifters for a query. Each lifter appears once, with their best qualifying lift.
    /// Unverified lifts are included unless `verifiedOnly` is set; ties use standard competition
    /// ranking (1, 2, 2, 4), and within a tie verified lifts and older lifts sort first.
    public static func rank(records: [LiftRecord], query: LeaderboardQuery, currentUserID: UUID?,
                            now: Date = Date(), calendar: Calendar = .current) -> [LeaderboardRow] {
        guard let exercise = ExerciseLibrary.exercise(id: query.exerciseID) else { return [] }
        let seasonStart = calendar.dateInterval(of: .month, for: now)?.start ?? now

        let eligible = records.filter { record in
            guard record.exerciseID == query.exerciseID,
                  StrengthCalculator.isRankable(reps: record.reps),
                  record.weightKg >= 0,
                  record.bodyweightKg > 0,
                  query.division.includes(record.sex) else { return false }
            if case .gym(let gymID) = query.scope, record.gymID != gymID { return false }
            if query.verifiedOnly && !record.verification.isVerified { return false }
            if record.flagCount >= flagHideThreshold && !record.verification.isVerified { return false }
            if query.timeframe == .thisSeason && record.performedAt < seasonStart { return false }
            return true
        }

        struct Scored {
            let record: LiftRecord
            let oneRepMax: Double
            let score: Double
        }

        var bestByLifter: [UUID: Scored] = [:]
        for record in eligible {
            let oneRepMax = StrengthCalculator.estimatedOneRepMax(for: record)
            let score = query.metric == .absolute
                ? oneRepMax
                : StrengthCalculator.relativeStrength(oneRepMaxKg: oneRepMax, bodyweightKg: record.bodyweightKg)
            let candidate = Scored(record: record, oneRepMax: oneRepMax, score: score)
            if let existing = bestByLifter[record.lifterID] {
                if isBetter(candidate.score, candidate.record, than: existing.score, existing.record) {
                    bestByLifter[record.lifterID] = candidate
                }
            } else {
                bestByLifter[record.lifterID] = candidate
            }
        }

        let sorted = bestByLifter.values.sorted { isBetter($0.score, $0.record, than: $1.score, $1.record) }

        var rows: [LeaderboardRow] = []
        rows.reserveCapacity(sorted.count)
        var previousScore: Double?
        var previousRank = 0
        for (index, item) in sorted.enumerated() {
            let rounded = (item.score * 100).rounded() / 100
            let rank = (previousScore == rounded) ? previousRank : index + 1
            previousScore = rounded
            previousRank = rank
            let tier = StrengthCalculator.tier(oneRepMaxKg: item.oneRepMax, bodyweightKg: item.record.bodyweightKg,
                                               exercise: exercise, sex: item.record.sex)
            rows.append(LeaderboardRow(rank: rank, record: item.record, estimatedOneRepMaxKg: item.oneRepMax,
                                       score: item.score, tier: tier,
                                       isCurrentUser: item.record.lifterID == currentUserID))
        }
        return rows
    }

    private static func isBetter(_ lhsScore: Double, _ lhs: LiftRecord, than rhsScore: Double, _ rhs: LiftRecord) -> Bool {
        let l = (lhsScore * 100).rounded()
        let r = (rhsScore * 100).rounded()
        if l != r { return l > r }
        if lhs.verification.isVerified != rhs.verification.isVerified { return lhs.verification.isVerified }
        if lhs.performedAt != rhs.performedAt { return lhs.performedAt < rhs.performedAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Converts a user's logged sets into leaderboard records.
    public static func records(from sessions: [WorkoutSession], profile: UserProfile) -> [LiftRecord] {
        sessions.flatMap { session in
            session.entries.flatMap { entry in
                entry.sets.filter { !$0.isWarmup }.map { set in
                    LiftRecord(id: set.id, lifterID: profile.id, displayName: profile.displayName,
                               username: profile.username, gymID: session.gymID, sex: profile.sex,
                               exerciseID: entry.exerciseID, weightKg: set.weightKg, reps: set.reps,
                               bodyweightKg: set.bodyweightKg, performedAt: set.performedAt,
                               verification: set.verification == .rejected ? .unverified : set.verification)
                }
            }
        }
    }

    /// Percentile (0–100) of the given rank: 100 means top of the board.
    public static func percentile(rank: Int, of total: Int) -> Double {
        guard total > 1 else { return 100 }
        return (1 - Double(rank - 1) / Double(total - 1)) * 100
    }
}
