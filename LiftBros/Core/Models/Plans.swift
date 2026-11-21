import Foundation

// MARK: - LiftBros Pro (consumer subscription)

public enum ProFeature: String, CaseIterable, Identifiable, Hashable, Sendable {
    case unlimitedEvidence
    case priorityReview
    case fullHistory
    case headToHead
    case csvExport
    case customRestTimer
    case proBadge

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .unlimitedEvidence: return "Unlimited evidence uploads"
        case .priorityReview: return "Priority review"
        case .fullHistory: return "All-time progress"
        case .headToHead: return "Head-to-head compare"
        case .csvExport: return "Export your data"
        case .customRestTimer: return "Custom rest timer"
        case .proBadge: return "Pro badge"
        }
    }

    public var detail: String {
        switch self {
        case .unlimitedEvidence:
            return "Free accounts get \(PlanLimits.freeEvidenceUploadsPerMonth) evidence uploads a month for the national board."
        case .priorityReview: return "Your evidence jumps the review queue, so you appear nationally sooner."
        case .fullHistory:
            return "Charts beyond the last \(PlanLimits.freeHistoryWeeks) weeks, for every lift."
        case .headToHead: return "Compare your best lifts against any lifter, lift by lift."
        case .csvExport: return "Download every set you've logged as a spreadsheet."
        case .customRestTimer: return "Set your own default rest time."
        case .proBadge: return "Stand out on every leaderboard."
        }
    }

    public var symbol: String {
        switch self {
        case .unlimitedEvidence: return "video.badge.checkmark"
        case .priorityReview: return "bolt.fill"
        case .fullHistory: return "chart.xyaxis.line"
        case .headToHead: return "person.2.fill"
        case .csvExport: return "square.and.arrow.up"
        case .customRestTimer: return "timer"
        case .proBadge: return "crown.fill"
        }
    }
}

public enum PlanLimits {
    public static let freeEvidenceUploadsPerMonth = 3
    public static let freeHistoryWeeks = 8

    /// Evidence uploads used this calendar month, from proof attached to sets.
    public static func evidenceUploadsThisMonth(in sessions: [WorkoutSession], now: Date = Date(),
                                                calendar: Calendar = .current) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: now) else { return 0 }
        return sessions.flatMap { $0.entries.flatMap(\.sets) }
            .compactMap(\.proof)
            .filter { month.contains($0.uploadedAt) }
            .count
    }

    public static func canUploadEvidence(isPro: Bool, usedThisMonth: Int) -> Bool {
        isPro || usedThisMonth < freeEvidenceUploadsPerMonth
    }

    /// Trims a progress series to the free history window.
    public static func visibleHistory(_ points: [ProgressPoint], isPro: Bool, now: Date = Date()) -> [ProgressPoint] {
        guard !isPro else { return points }
        let cutoff = now.addingTimeInterval(-Double(freeHistoryWeeks) * 7 * 86_400)
        return points.filter { $0.date >= cutoff }
    }
}

public enum ProProduct: String, CaseIterable, Sendable {
    case monthly = "com.liftbros.pro.monthly"
    case yearly = "com.liftbros.pro.yearly"

    /// Fallback display prices when the App Store can't be reached (e.g. sideloaded builds).
    public var fallbackPrice: String {
        switch self {
        case .monthly: return "£3.99"
        case .yearly: return "£29.99"
        }
    }

    public var periodLabel: String {
        switch self {
        case .monthly: return "per month"
        case .yearly: return "per year"
        }
    }
}

// MARK: - Gym partnerships (B2B leaderboard screens)

public enum GymPartnerTier: String, Codable, CaseIterable, Hashable, Sendable {
    /// One in-gym screen showing the honour-system gym leaderboards.
    case screen
    /// Multiple screens, branded display, monthly challenges and member analytics.
    case screenPlus
    /// Multi-site chains: everything in Screen+, plus gym-vs-gym competitions across sites.
    case network

    public var displayName: String {
        switch self {
        case .screen: return "Screen"
        case .screenPlus: return "Screen+"
        case .network: return "Network"
        }
    }

    /// Indicative monthly price per site in GBP (ex VAT); refine with pilot gyms.
    public var monthlyPriceGBP: Int? {
        switch self {
        case .screen: return 99
        case .screenPlus: return 199
        case .network: return nil
        }
    }

    public var maxScreens: Int {
        switch self {
        case .screen: return 1
        case .screenPlus: return 4
        case .network: return 20
        }
    }

    public var includesChallenges: Bool { self != .screen }
    public var includesBranding: Bool { self != .screen }
}

public enum PartnershipStatus: String, Codable, Hashable, Sendable {
    case trial, active, pastDue, cancelled

    public var isLive: Bool { self == .trial || self == .active }
}

public struct GymChallenge: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var exerciseID: String
    public var metric: LeaderboardMetric
    public var startsAt: Date
    public var endsAt: Date
    public var prize: String?

    public init(id: UUID = UUID(), title: String, exerciseID: String, metric: LeaderboardMetric, startsAt: Date,
                endsAt: Date, prize: String? = nil) {
        self.id = id
        self.title = title
        self.exerciseID = exerciseID
        self.metric = metric
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.prize = prize
    }

    public func isRunning(at date: Date = Date()) -> Bool { (startsAt...endsAt).contains(date) }
}

/// Configuration for what an in-gym screen shows.
public struct ScreenConfig: Codable, Hashable, Sendable {
    public var exerciseIDs: [String]
    public var metrics: [LeaderboardMetric]
    public var rotationSeconds: Int
    public var rowsShown: Int
    public var accentHex: String?

    public init(exerciseIDs: [String] = ["bench-press", "back-squat", "deadlift", "lat-pulldown", "leg-press"],
                metrics: [LeaderboardMetric] = [.absolute, .relative], rotationSeconds: Int = 12,
                rowsShown: Int = 10, accentHex: String? = nil) {
        self.exerciseIDs = exerciseIDs
        self.metrics = metrics
        self.rotationSeconds = rotationSeconds
        self.rowsShown = rowsShown
        self.accentHex = accentHex
    }
}

/// A gym's subscription to LiftBros leaderboard screens.
public struct GymPartnership: Identifiable, Codable, Hashable, Sendable {
    public var id: String { gymID }
    public let gymID: String
    public var tier: GymPartnerTier
    public var status: PartnershipStatus
    /// Code staff enter on a screen device (iPad, Apple TV, smart-TV browser) to pair it.
    public var pairingCode: String
    public var screen: ScreenConfig
    public var challenge: GymChallenge?
    public var renewsAt: Date?

    public init(gymID: String, tier: GymPartnerTier, status: PartnershipStatus, pairingCode: String,
                screen: ScreenConfig = ScreenConfig(), challenge: GymChallenge? = nil, renewsAt: Date? = nil) {
        self.gymID = gymID
        self.tier = tier
        self.status = status
        self.pairingCode = pairingCode
        self.screen = screen
        self.challenge = challenge
        self.renewsAt = renewsAt
    }

    /// The challenge to show, respecting what the tier includes.
    public func activeChallenge(at date: Date = Date()) -> GymChallenge? {
        guard tier.includesChallenges, let challenge, challenge.isRunning(at: date) else { return nil }
        return challenge
    }

    public static func normalise(code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
