import Foundation

/// A single ranked lift as the leaderboard sees it. Both community data from the backend
/// and the signed-in user's own sets are flattened into this shape.
public struct LiftRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var lifterID: UUID
    public var displayName: String
    public var username: String
    public var gymID: String
    public var sex: Sex
    public var exerciseID: String
    public var weightKg: Double
    public var reps: Int
    public var bodyweightKg: Double
    public var performedAt: Date
    public var verification: VerificationStatus
    public var flagCount: Int
    public var isPro: Bool

    public init(id: UUID = UUID(), lifterID: UUID, displayName: String, username: String, gymID: String, sex: Sex,
                exerciseID: String, weightKg: Double, reps: Int, bodyweightKg: Double, performedAt: Date,
                verification: VerificationStatus, flagCount: Int = 0, isPro: Bool = false) {
        self.id = id
        self.lifterID = lifterID
        self.displayName = displayName
        self.username = username
        self.gymID = gymID
        self.sex = sex
        self.exerciseID = exerciseID
        self.weightKg = weightKg
        self.reps = reps
        self.bodyweightKg = bodyweightKg
        self.performedAt = performedAt
        self.verification = verification
        self.flagCount = flagCount
        self.isPro = isPro
    }
}

public enum LeaderboardScope: Hashable, Sendable {
    /// One gym's members. Honour system: every logged lift counts.
    case gym(String)
    /// Every LiftBros member in the UK. Top 100 shown; evidence required.
    case unitedKingdom
}

public enum LeaderboardMetric: String, CaseIterable, Codable, Hashable, Sendable {
    /// Estimated one-rep max in kg.
    case absolute
    /// Estimated one-rep max divided by bodyweight.
    case relative

    public var displayName: String {
        switch self {
        case .absolute: return "Heaviest"
        case .relative: return "Pound for Pound"
        }
    }
}

public enum Division: String, CaseIterable, Hashable, Sendable {
    case open, men, women

    public var displayName: String {
        switch self {
        case .open: return "Open"
        case .men: return "Men"
        case .women: return "Women"
        }
    }

    func includes(_ sex: Sex) -> Bool {
        switch self {
        case .open: return true
        case .men: return sex == .male
        case .women: return sex == .female
        }
    }
}

public enum LeaderboardTimeframe: String, CaseIterable, Hashable, Sendable {
    case allTime, thisSeason

    public var displayName: String {
        switch self {
        case .allTime: return "All time"
        case .thisSeason: return "This month"
        }
    }
}

public struct LeaderboardQuery: Hashable, Sendable {
    public var exerciseID: String
    public var scope: LeaderboardScope
    public var metric: LeaderboardMetric
    public var division: Division
    public var timeframe: LeaderboardTimeframe
    public var verifiedOnly: Bool

    public init(exerciseID: String, scope: LeaderboardScope, metric: LeaderboardMetric = .absolute,
                division: Division = .open, timeframe: LeaderboardTimeframe = .allTime, verifiedOnly: Bool = false) {
        self.exerciseID = exerciseID
        self.scope = scope
        self.metric = metric
        self.division = division
        self.timeframe = timeframe
        self.verifiedOnly = verifiedOnly
    }
}

public struct LeaderboardRow: Identifiable, Hashable, Sendable {
    public var id: UUID { record.lifterID }
    public let rank: Int
    public let record: LiftRecord
    public let estimatedOneRepMaxKg: Double
    /// The value the board is sorted by: kg for `.absolute`, ×bodyweight for `.relative`.
    public let score: Double
    public let tier: StrengthTier
    public let isCurrentUser: Bool
}

public struct PublicLifterProfile: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let username: String
    public let gymID: String
    public let sex: Sex
    public let bodyweightKg: Double
    public let bodyFatPercent: Double?
    public let yearsLifting: Double
    public let progressVisibility: Audience
    public let bodyStatsVisibility: Audience
    public let bestLifts: [LiftRecord]

    public init(id: UUID, displayName: String, username: String, gymID: String, sex: Sex, bodyweightKg: Double,
                bodyFatPercent: Double?, yearsLifting: Double, progressVisibility: Audience,
                bodyStatsVisibility: Audience, bestLifts: [LiftRecord]) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.gymID = gymID
        self.sex = sex
        self.bodyweightKg = bodyweightKg
        self.bodyFatPercent = bodyFatPercent
        self.yearsLifting = yearsLifting
        self.progressVisibility = progressVisibility
        self.bodyStatsVisibility = bodyStatsVisibility
        self.bestLifts = bestLifts
    }
}
