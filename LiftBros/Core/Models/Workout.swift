import Foundation

public enum VerificationStatus: String, Codable, CaseIterable, Hashable, Sendable {
    /// No proof uploaded. Still counts on leaderboards, but marked as unverified.
    case unverified
    /// Proof uploaded and waiting for review.
    case pending
    /// Proof reviewed and accepted.
    case verified
    /// Proof reviewed and not accepted (e.g. depth, lockout or the weight couldn't be seen).
    case rejected

    public var displayName: String {
        switch self {
        case .unverified: return "Unverified"
        case .pending: return "Pending review"
        case .verified: return "Verified"
        case .rejected: return "Proof rejected"
        }
    }

    public var isVerified: Bool { self == .verified }
}

public enum ProofKind: String, Codable, Hashable, Sendable {
    case video, photo
}

public struct ProofMedia: Codable, Hashable, Sendable {
    public var kind: ProofKind
    /// File name inside the app's Proofs directory.
    public var filename: String
    public var uploadedAt: Date
    /// Set once the backend has stored the file.
    public var remoteURL: URL?

    public init(kind: ProofKind, filename: String, uploadedAt: Date = Date(), remoteURL: URL? = nil) {
        self.kind = kind
        self.filename = filename
        self.uploadedAt = uploadedAt
        self.remoteURL = remoteURL
    }
}

public struct LiftSet: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// Weight as entered (per dumbbell for dumbbell lifts, added weight for weighted pull-ups/dips).
    public var weightKg: Double
    public var reps: Int
    /// Rate of perceived exertion, 6–10.
    public var rpe: Double?
    public var performedAt: Date
    /// Bodyweight when the set was performed, used for relative strength scores.
    public var bodyweightKg: Double
    public var proof: ProofMedia?
    public var verification: VerificationStatus
    public var isWarmup: Bool

    public init(id: UUID = UUID(), weightKg: Double, reps: Int, rpe: Double? = nil, performedAt: Date = Date(),
                bodyweightKg: Double, proof: ProofMedia? = nil, verification: VerificationStatus = .unverified,
                isWarmup: Bool = false) {
        self.id = id
        self.weightKg = weightKg
        self.reps = reps
        self.rpe = rpe
        self.performedAt = performedAt
        self.bodyweightKg = bodyweightKg
        self.proof = proof
        self.verification = verification
        self.isWarmup = isWarmup
    }
}

public struct ExerciseEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var exerciseID: String
    public var sets: [LiftSet]
    public var notes: String

    public init(id: UUID = UUID(), exerciseID: String, sets: [LiftSet] = [], notes: String = "") {
        self.id = id
        self.exerciseID = exerciseID
        self.sets = sets
        self.notes = notes
    }

    public var exercise: Exercise? { ExerciseLibrary.exercise(id: exerciseID) }
}

public struct WorkoutSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var gymID: String
    public var startedAt: Date
    public var endedAt: Date?
    public var entries: [ExerciseEntry]
    public var notes: String

    public init(id: UUID = UUID(), title: String, gymID: String, startedAt: Date = Date(), endedAt: Date? = nil,
                entries: [ExerciseEntry] = [], notes: String = "") {
        self.id = id
        self.title = title
        self.gymID = gymID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.entries = entries
        self.notes = notes
    }

    public var isFinished: Bool { endedAt != nil }

    public var workingSets: [LiftSet] { entries.flatMap { $0.sets.filter { !$0.isWarmup } } }

    public var totalVolumeKg: Double {
        entries.reduce(0) { total, entry in
            let multiplier = (entry.exercise?.isPerHand ?? false) ? 2.0 : 1.0
            return total + entry.sets.filter { !$0.isWarmup }.reduce(0) { $0 + $1.weightKg * Double($1.reps) * multiplier }
        }
    }

    public var duration: TimeInterval? { endedAt.map { $0.timeIntervalSince(startedAt) } }

    public static func defaultTitle(for date: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<12: return "Morning Session"
        case 12..<17: return "Afternoon Session"
        default: return "Evening Session"
        }
    }
}
