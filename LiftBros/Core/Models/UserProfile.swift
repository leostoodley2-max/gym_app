import Foundation

public enum Sex: String, Codable, CaseIterable, Hashable, Sendable {
    case male, female, preferNotToSay

    public var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

public enum WeightUnit: String, Codable, CaseIterable, Hashable, Sendable {
    case kg, lb

    public static let poundsPerKg = 2.2046226218

    public func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg * Self.poundsPerKg }
    public func toKg(_ value: Double) -> Double { self == .kg ? value : value / Self.poundsPerKg }
    public var symbol: String { rawValue }
}

public enum TrainingGoal: String, Codable, CaseIterable, Hashable, Sendable {
    case strength, hypertrophy, powerlifting, generalFitness, fatLoss

    public var displayName: String {
        switch self {
        case .strength: return "Get stronger"
        case .hypertrophy: return "Build muscle"
        case .powerlifting: return "Powerlifting"
        case .generalFitness: return "General fitness"
        case .fatLoss: return "Lose fat"
        }
    }
}

public enum Audience: String, Codable, CaseIterable, Hashable, Sendable {
    case everyone, gymMembers, onlyMe

    public var displayName: String {
        switch self {
        case .everyone: return "Everyone"
        case .gymMembers: return "My gym only"
        case .onlyMe: return "Only me"
        }
    }
}

public struct PrivacySettings: Codable, Hashable, Sendable {
    /// Who can see your workout history and progress charts.
    public var progressVisibility: Audience
    /// Who can see body stats (body fat, height, age). Private by default.
    public var bodyStatsVisibility: Audience
    /// Whether your best lifts appear on leaderboards at all.
    public var showOnLeaderboards: Bool

    public init(progressVisibility: Audience = .everyone,
                bodyStatsVisibility: Audience = .onlyMe,
                showOnLeaderboards: Bool = true) {
        self.progressVisibility = progressVisibility
        self.bodyStatsVisibility = bodyStatsVisibility
        self.showOnLeaderboards = showOnLeaderboards
    }
}

public struct UserProfile: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var displayName: String
    public var username: String
    public var gymID: String
    public var sex: Sex
    public var birthYear: Int?
    public var heightCm: Double?
    public var bodyweightKg: Double
    public var bodyFatPercent: Double?
    public var yearsLifting: Double
    public var trainingDaysPerWeek: Int
    public var goal: TrainingGoal
    public var bio: String
    public var unit: WeightUnit
    public var privacy: PrivacySettings
    public var createdAt: Date

    public init(id: UUID = UUID(), displayName: String, username: String, gymID: String, sex: Sex,
                birthYear: Int? = nil, heightCm: Double? = nil, bodyweightKg: Double, bodyFatPercent: Double? = nil,
                yearsLifting: Double = 0, trainingDaysPerWeek: Int = 3, goal: TrainingGoal = .strength,
                bio: String = "", unit: WeightUnit = .kg, privacy: PrivacySettings = PrivacySettings(),
                createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.username = username
        self.gymID = gymID
        self.sex = sex
        self.birthYear = birthYear
        self.heightCm = heightCm
        self.bodyweightKg = bodyweightKg
        self.bodyFatPercent = bodyFatPercent
        self.yearsLifting = yearsLifting
        self.trainingDaysPerWeek = trainingDaysPerWeek
        self.goal = goal
        self.bio = bio
        self.unit = unit
        self.privacy = privacy
        self.createdAt = createdAt
    }

    public func age(asOf date: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let birthYear else { return nil }
        return calendar.component(.year, from: date) - birthYear
    }

    /// Lean body mass, when body fat is known.
    public var leanMassKg: Double? {
        guard let bodyFatPercent else { return nil }
        return bodyweightKg * (1 - bodyFatPercent / 100)
    }

    /// Body-mass index, when height is known.
    public var bmi: Double? {
        guard let heightCm, heightCm > 0 else { return nil }
        let m = heightCm / 100
        return bodyweightKg / (m * m)
    }

    public var experienceLabel: String {
        switch yearsLifting {
        case ..<1: return "Beginner"
        case ..<3: return "Intermediate"
        case ..<6: return "Advanced"
        default: return "Veteran"
        }
    }
}

public struct BodyMetricEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var date: Date
    public var bodyweightKg: Double
    public var bodyFatPercent: Double?

    public init(id: UUID = UUID(), date: Date = Date(), bodyweightKg: Double, bodyFatPercent: Double? = nil) {
        self.id = id
        self.date = date
        self.bodyweightKg = bodyweightKg
        self.bodyFatPercent = bodyFatPercent
    }
}
