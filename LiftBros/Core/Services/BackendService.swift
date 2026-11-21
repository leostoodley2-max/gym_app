import Foundation

public enum FlagReason: String, CaseIterable, Codable, Hashable, Sendable {
    case implausibleWeight, badForm, wrongExercise, other

    public var displayName: String {
        switch self {
        case .implausibleWeight: return "Weight looks implausible"
        case .badForm: return "Didn't meet standards (depth, lockout)"
        case .wrongExercise: return "Wrong exercise / machine"
        case .other: return "Something else"
        }
    }
}

/// Everything LiftBros needs from a server. `MockBackendService` implements it locally so the app
/// works without a network. Swap in a real implementation (e.g. Supabase or Firebase) without touching the UI.
/// See docs/BACKEND.md for the suggested schema.
public protocol BackendService: AnyObject, Sendable {
    func fetchGyms() async throws -> [Gym]

    /// Best lifts from other members for an exercise. Implementations may return several sets per lifter.
    func fetchCommunityRecords(exerciseID: String) async throws -> [LiftRecord]

    /// Uploads the signed-in user's sets so others can see them on leaderboards.
    func publish(records: [LiftRecord]) async throws

    /// Removes the user's records from public leaderboards (e.g. after opting out).
    func unpublishRecords(lifterID: UUID) async throws

    /// Uploads evidence for a set. Returns the status after upload, normally `.pending`.
    /// `priority` puts Pro members at the front of the review queue.
    func submitProof(setID: UUID, fileURL: URL, kind: ProofKind, priority: Bool) async throws -> VerificationStatus

    /// Polls the review outcome for a set with proof.
    func verificationStatus(setID: UUID) async throws -> VerificationStatus

    /// Reports a suspicious lift for moderator review.
    func flag(recordID: UUID, reason: FlagReason) async throws

    func fetchLifterProfile(id: UUID) async throws -> PublicLifterProfile?

    /// Progress history for another lifter. Returns nil when their progress is private to you.
    func fetchLifterProgress(id: UUID, exerciseID: String, viewerGymID: String) async throws -> [ProgressPoint]?

    // MARK: Gym partnerships (B2B screens)

    /// The gym's LiftBros screen subscription, if it has one.
    func fetchPartnership(gymID: String) async throws -> GymPartnership?

    /// Pairs a screen device using the code from the gym's partner dashboard.
    func pairScreen(code: String) async throws -> GymPartnership?
}
