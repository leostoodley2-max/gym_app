import Foundation

/// Where the signed-in lifter stands on the national (UK-wide) board.
public struct NationalStanding: Hashable, Sendable {
    public enum Status: Hashable, Sendable {
        /// No rankable lift for this exercise yet.
        case noLift
        /// Your best lift is verified and inside the top 100, so it is shown on the board.
        case listed
        /// Your best lift would make the top 100, but evidence is needed before it is shown.
        case needsEvidence
        /// Evidence is uploaded and in review; you'll appear once it's approved.
        case pendingReview
        /// Your best lift ranks outside the top 100 shown nationally.
        case outsideTopList
    }

    public let status: Status
    /// Where your best lift would rank if it were verified (1-based).
    public let provisionalRank: Int?
    /// Your rank on the visible board, if a verified lift of yours is listed.
    public let listedRank: Int?
    /// How many lifters are ranked nationally (verified lifters plus you).
    public let totalRanked: Int
    /// Your best lift for the exercise (may be unverified).
    public let bestRecord: LiftRecord?
    public let bestScore: Double?
}

public enum LeaderboardEngine {
    /// Unverified lifts flagged this many times are hidden until proof is provided.
    public static let flagHideThreshold = 3
    /// How many places the national board shows.
    public static let nationalListSize = 100

    /// Ranks lifters for a query. Each lifter appears once, with their best qualifying lift.
    ///
    /// - Gym boards run on an **honour system**: every lift counts, verified or not.
    /// - The national board only shows **verified** lifts and only the top `nationalListSize` places.
    ///
    /// Ties use standard competition ranking (1, 2, 2, 4); within a tie verified and older lifts sort first.
    public static func rank(records: [LiftRecord], query: LeaderboardQuery, currentUserID: UUID?,
                            now: Date = Date(), calendar: Calendar = .current) -> [LeaderboardRow] {
        var effective = query
        if case .unitedKingdom = query.scope { effective.verifiedOnly = true }
        let rows = rankAll(records: records, query: effective, currentUserID: currentUserID, now: now, calendar: calendar)
        if case .unitedKingdom = query.scope {
            return Array(rows.prefix(nationalListSize))
        }
        return rows
    }

    /// Works out where the current user stands nationally, including lifts that still need evidence.
    public static func nationalStanding(records: [LiftRecord], query: LeaderboardQuery, currentUserID: UUID?,
                                        now: Date = Date(), calendar: Calendar = .current) -> NationalStanding {
        var verifiedQuery = query
        verifiedQuery.scope = .unitedKingdom
        verifiedQuery.verifiedOnly = true
        let verifiedRows = rankAll(records: records, query: verifiedQuery, currentUserID: currentUserID,
                                   now: now, calendar: calendar)
        let others = verifiedRows.filter { !$0.isCurrentUser }

        var anyQuery = query
        anyQuery.scope = .unitedKingdom
        anyQuery.verifiedOnly = false
        let mine = rankAll(records: records.filter { $0.lifterID == currentUserID }, query: anyQuery,
                           currentUserID: currentUserID, now: now, calendar: calendar).first

        guard let mine else {
            return NationalStanding(status: .noLift, provisionalRank: nil, listedRank: nil,
                                    totalRanked: others.count, bestRecord: nil, bestScore: nil)
        }
        let myScore = rounded(mine.score)
        let provisionalRank = others.filter { rounded($0.score) > myScore }.count + 1
        let listedRow = verifiedRows.first { $0.isCurrentUser && $0.rank <= nationalListSize }
        let total = others.count + 1

        let status: NationalStanding.Status
        switch mine.record.verification {
        case .verified:
            status = provisionalRank <= nationalListSize ? .listed : .outsideTopList
        case .pending:
            status = provisionalRank <= nationalListSize ? .pendingReview : .outsideTopList
        case .unverified, .rejected:
            status = provisionalRank <= nationalListSize ? .needsEvidence : .outsideTopList
        }
        return NationalStanding(status: status, provisionalRank: provisionalRank, listedRank: listedRow?.rank,
                                totalRanked: total, bestRecord: mine.record, bestScore: mine.score)
    }

    private static func rounded(_ score: Double) -> Double { (score * 100).rounded() }

    static func rankAll(records: [LiftRecord], query: LeaderboardQuery, currentUserID: UUID?,
                        now: Date, calendar: Calendar) -> [LeaderboardRow] {
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
            let score = rounded(item.score)
            let rank = (previousScore == score) ? previousRank : index + 1
            previousScore = score
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
        let l = rounded(lhsScore)
        let r = rounded(rhsScore)
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
