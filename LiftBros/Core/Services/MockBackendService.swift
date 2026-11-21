import Foundation

/// In-memory backend with a generated sample community at real Worcestershire gyms. Evidence is "reviewed"
/// automatically after `reviewDelay` seconds (a third of that for priority/Pro) so the flow can be demoed.
public actor MockBackendService: BackendService {
    private let community: MockCommunity.Community
    private var recordsByExercise: [String: [LiftRecord]]
    private var publishedByUser: [UUID: [LiftRecord]] = [:]
    private var proofSubmissions: [UUID: (date: Date, priority: Bool)] = [:]
    private var flags: [UUID: Int] = [:]
    private let reviewDelay: TimeInterval
    private let partnerships: [String: GymPartnership]

    public init(seed: UInt64 = 2026, reviewDelay: TimeInterval = 6) {
        let community = MockCommunity.generate(seed: seed)
        self.community = community
        self.recordsByExercise = Dictionary(grouping: community.records, by: \.exerciseID)
        self.reviewDelay = reviewDelay
        self.partnerships = Dictionary(uniqueKeysWithValues: MockCommunity.samplePartnerships().map { ($0.gymID, $0) })
    }

    public func fetchGyms() async throws -> [Gym] { MockCommunity.gyms }

    public func fetchCommunityRecords(exerciseID: String) async throws -> [LiftRecord] {
        (recordsByExercise[exerciseID] ?? []).map { record in
            var copy = record
            copy.flagCount = flags[record.id] ?? 0
            return copy
        }
    }

    public func publish(records: [LiftRecord]) async throws {
        guard let lifterID = records.first?.lifterID else { return }
        publishedByUser[lifterID] = records
    }

    public func unpublishRecords(lifterID: UUID) async throws {
        publishedByUser[lifterID] = nil
    }

    public func submitProof(setID: UUID, fileURL: URL, kind: ProofKind, priority: Bool) async throws -> VerificationStatus {
        proofSubmissions[setID] = (Date(), priority)
        return .pending
    }

    public func verificationStatus(setID: UUID) async throws -> VerificationStatus {
        guard let submitted = proofSubmissions[setID] else {
            // Unknown to this in-memory backend (e.g. after an app relaunch): treat as just submitted.
            proofSubmissions[setID] = (Date(), false)
            return reviewDelay <= 0 ? .verified : .pending
        }
        let delay = submitted.priority ? reviewDelay / 3 : reviewDelay
        return Date().timeIntervalSince(submitted.date) >= delay ? .verified : .pending
    }

    public func flag(recordID: UUID, reason: FlagReason) async throws {
        flags[recordID, default: 0] += 1
    }

    public func fetchLifterProfile(id: UUID) async throws -> PublicLifterProfile? {
        guard let lifter = community.lifters.first(where: { $0.id == id }) else { return nil }
        let lifts = community.records.filter { $0.lifterID == id }
        return PublicLifterProfile(
            id: lifter.id, displayName: lifter.displayName, username: lifter.username, gymID: lifter.gymID,
            sex: lifter.sex, bodyweightKg: lifter.bodyweightKg, bodyFatPercent: lifter.bodyFatPercent,
            yearsLifting: lifter.yearsLifting, progressVisibility: lifter.progressVisibility,
            bodyStatsVisibility: lifter.bodyStatsVisibility, bestLifts: lifts)
    }

    public func fetchLifterProgress(id: UUID, exerciseID: String, viewerGymID: String) async throws -> [ProgressPoint]? {
        guard let lifter = community.lifters.first(where: { $0.id == id }) else { return nil }
        switch lifter.progressVisibility {
        case .onlyMe: return nil
        case .gymMembers where lifter.gymID != viewerGymID: return nil
        default: break
        }
        guard let record = community.records.first(where: { $0.lifterID == id && $0.exerciseID == exerciseID }) else {
            return []
        }
        return MockCommunity.progressHistory(endingAt: StrengthCalculator.estimatedOneRepMax(for: record),
                                             lifterID: id, exerciseID: exerciseID)
    }

    public func fetchPartnership(gymID: String) async throws -> GymPartnership? {
        partnerships[gymID]
    }

    public func pairScreen(code: String) async throws -> GymPartnership? {
        let wanted = GymPartnership.normalise(code: code)
        return partnerships.values.first { GymPartnership.normalise(code: $0.pairingCode) == wanted && $0.status.isLive }
    }
}
