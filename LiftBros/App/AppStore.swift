import Foundation
import Observation

struct PRCelebration: Equatable, Identifiable {
    let id = UUID()
    let exerciseName: String
    let oneRepMaxKg: Double
}

/// A located set plus the context needed to display it.
struct SetContext {
    let set: LiftSet
    let exerciseID: String
    let gymID: String
    let isInActiveSession: Bool
}

/// Proof media picked from the photo library, ready to be stored.
enum PickedProof {
    case video(URL)
    case photo(Data, fileExtension: String)

    var kind: ProofKind {
        switch self {
        case .video: return .video
        case .photo: return .photo
        }
    }
}

/// Single source of truth for the app. All mutations go through here, are saved to disk
/// immediately (offline-first) and then synced to the backend in the background.
@MainActor
@Observable
final class AppStore {
    private(set) var profile: UserProfile?
    private(set) var sessions: [WorkoutSession] = []
    private(set) var activeSession: WorkoutSession?
    private(set) var bodyMetrics: [BodyMetricEntry] = []
    private(set) var gyms: [Gym] = MockCommunity.gyms
    /// Bumped on any change that could affect leaderboards, so views know to re-rank.
    private(set) var dataVersion = 0
    var prCelebration: PRCelebration?

    @ObservationIgnored private var communityCache: [String: [LiftRecord]] = [:]
    @ObservationIgnored let backend: BackendService
    @ObservationIgnored let local: LocalStore

    init(backend: BackendService = MockBackendService(), local: LocalStore = LocalStore()) {
        self.backend = backend
        self.local = local
        let data = local.load()
        profile = data.profile
        sessions = data.sessions
        activeSession = data.activeSession
        bodyMetrics = data.bodyMetrics
        Task { await loadGyms() }
    }

    // MARK: - Derived data

    var unit: WeightUnit { profile?.unit ?? .kg }

    var currentGym: Gym? { profile.flatMap { gym(id: $0.gymID) } }

    func gym(id: String) -> Gym? { gyms.first { $0.id == id } }

    /// Finished sessions plus the one in progress, newest first.
    var allSessions: [WorkoutSession] {
        (sessions + [activeSession].compactMap { $0 }).sorted { $0.startedAt > $1.startedAt }
    }

    var finishedSessions: [WorkoutSession] { sessions.sorted { $0.startedAt > $1.startedAt } }

    var personalBests: [String: PersonalBest] { ProgressAnalyzer.personalBests(in: allSessions) }

    var myRecords: [LiftRecord] {
        guard let profile, profile.privacy.showOnLeaderboards else { return [] }
        return LeaderboardEngine.records(from: allSessions, profile: profile)
    }

    var loggedExerciseIDs: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in allSessions.reversed() {
            for entry in session.entries where !entry.sets.isEmpty && seen.insert(entry.exerciseID).inserted {
                result.append(entry.exerciseID)
            }
        }
        return result
    }

    // MARK: - Profile

    func completeOnboarding(_ newProfile: UserProfile) {
        profile = newProfile
        bodyMetrics = [BodyMetricEntry(bodyweightKg: newProfile.bodyweightKg, bodyFatPercent: newProfile.bodyFatPercent)]
        persist()
    }

    func saveProfile(_ updated: UserProfile) {
        let previous = profile
        profile = updated
        if previous?.bodyweightKg != updated.bodyweightKg || previous?.bodyFatPercent != updated.bodyFatPercent {
            bodyMetrics.append(BodyMetricEntry(bodyweightKg: updated.bodyweightKg, bodyFatPercent: updated.bodyFatPercent))
        }
        if let activeSession, previous?.gymID != updated.gymID, activeSession.entries.allSatisfy({ $0.sets.isEmpty }) {
            self.activeSession?.gymID = updated.gymID
        }
        if previous?.privacy.showOnLeaderboards == true && !updated.privacy.showOnLeaderboards {
            let id = updated.id
            Task { try? await backend.unpublishRecords(lifterID: id) }
        }
        persist()
        sync()
    }

    func updateProfile(_ transform: (inout UserProfile) -> Void) {
        guard var copy = profile else { return }
        transform(&copy)
        saveProfile(copy)
    }

    func logBodyMetric(bodyweightKg: Double, bodyFatPercent: Double?, date: Date = Date()) {
        bodyMetrics.append(BodyMetricEntry(date: date, bodyweightKg: bodyweightKg, bodyFatPercent: bodyFatPercent))
        bodyMetrics.sort { $0.date < $1.date }
        if var profile, date >= (bodyMetrics.last?.date ?? date) {
            profile.bodyweightKg = bodyweightKg
            if let bodyFatPercent { profile.bodyFatPercent = bodyFatPercent }
            self.profile = profile
        }
        persist()
    }

    func deleteBodyMetric(id: UUID) {
        bodyMetrics.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Workouts

    func startWorkout() {
        guard activeSession == nil, let profile else { return }
        activeSession = WorkoutSession(title: WorkoutSession.defaultTitle(for: Date()), gymID: profile.gymID)
        persist()
    }

    func renameActiveWorkout(_ title: String) {
        activeSession?.title = title
        persist()
    }

    func addExercise(_ exerciseID: String) {
        guard activeSession != nil else { return }
        activeSession?.entries.append(ExerciseEntry(exerciseID: exerciseID))
        persist()
    }

    func removeEntry(id: UUID) {
        guard let entry = activeSession?.entries.first(where: { $0.id == id }) else { return }
        entry.sets.compactMap(\.proof).forEach(local.deleteProof)
        activeSession?.entries.removeAll { $0.id == id }
        changed()
    }

    func lastSet(inEntry entryID: UUID) -> LiftSet? {
        activeSession?.entries.first { $0.id == entryID }?.sets.last
    }

    /// The most recent working set ever logged for an exercise, to pre-fill the next one.
    func lastSet(forExercise exerciseID: String) -> LiftSet? {
        for session in allSessions {
            if let set = session.entries.last(where: { $0.exerciseID == exerciseID })?.sets.last(where: { !$0.isWarmup }) {
                return set
            }
        }
        return nil
    }

    @discardableResult
    func addSet(entryID: UUID, weightKg: Double, reps: Int, rpe: Double?, isWarmup: Bool) -> LiftSet? {
        guard let profile,
              let index = activeSession?.entries.firstIndex(where: { $0.id == entryID }),
              let exerciseID = activeSession?.entries[index].exerciseID else { return nil }
        let set = LiftSet(weightKg: weightKg, reps: reps, rpe: rpe, bodyweightKg: profile.bodyweightKg, isWarmup: isWarmup)
        activeSession?.entries[index].sets.append(set)
        if ProgressAnalyzer.isPersonalRecord(set, exerciseID: exerciseID, in: allSessions),
           loggedSetCount(exerciseID: exerciseID) > 1,
           let exercise = ExerciseLibrary.exercise(id: exerciseID) {
            prCelebration = PRCelebration(exerciseName: exercise.name,
                                          oneRepMaxKg: StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise))
        }
        changed()
        return set
    }

    private func loggedSetCount(exerciseID: String) -> Int {
        allSessions.reduce(0) { total, session in
            total + session.entries.filter { $0.exerciseID == exerciseID }.reduce(0) { $0 + $1.sets.count }
        }
    }

    func deleteSet(id: UUID) {
        if let context = findSet(id: id), let proof = context.set.proof { local.deleteProof(proof) }
        if activeSession != nil {
            for i in activeSession!.entries.indices { activeSession!.entries[i].sets.removeAll { $0.id == id } }
        }
        for s in sessions.indices {
            for e in sessions[s].entries.indices { sessions[s].entries[e].sets.removeAll { $0.id == id } }
        }
        changed()
    }

    func finishWorkout() {
        guard var session = activeSession else { return }
        session.entries.removeAll { $0.sets.isEmpty }
        session.endedAt = Date()
        if !session.entries.isEmpty { sessions.append(session) }
        activeSession = nil
        changed()
    }

    func discardWorkout() {
        activeSession?.entries.flatMap(\.sets).compactMap(\.proof).forEach(local.deleteProof)
        activeSession = nil
        changed()
    }

    func deleteSession(id: UUID) {
        sessions.first(where: { $0.id == id })?.entries.flatMap(\.sets).compactMap(\.proof).forEach(local.deleteProof)
        sessions.removeAll { $0.id == id }
        changed()
    }

    func session(id: UUID) -> WorkoutSession? {
        if activeSession?.id == id { return activeSession }
        return sessions.first { $0.id == id }
    }

    // MARK: - Sets & proof

    func findSet(id: UUID) -> SetContext? {
        if let active = activeSession {
            for entry in active.entries {
                if let set = entry.sets.first(where: { $0.id == id }) {
                    return SetContext(set: set, exerciseID: entry.exerciseID, gymID: active.gymID, isInActiveSession: true)
                }
            }
        }
        for session in sessions {
            for entry in session.entries {
                if let set = entry.sets.first(where: { $0.id == id }) {
                    return SetContext(set: set, exerciseID: entry.exerciseID, gymID: session.gymID, isInActiveSession: false)
                }
            }
        }
        return nil
    }

    private func mutateSet(id: UUID, _ body: (inout LiftSet) -> Void) {
        if let active = activeSession {
            for e in active.entries.indices {
                if let s = active.entries[e].sets.firstIndex(where: { $0.id == id }) {
                    body(&activeSession!.entries[e].sets[s])
                    return
                }
            }
        }
        for w in sessions.indices {
            for e in sessions[w].entries.indices {
                if let s = sessions[w].entries[e].sets.firstIndex(where: { $0.id == id }) {
                    body(&sessions[w].entries[e].sets[s])
                    return
                }
            }
        }
    }

    func attachProof(_ picked: PickedProof, toSet setID: UUID) throws {
        let filename: String
        switch picked {
        case .video(let url):
            filename = try local.importProof(from: url, kind: .video)
            try? FileManager.default.removeItem(at: url)
        case .photo(let data, let ext):
            filename = try local.saveProof(data: data, fileExtension: ext)
        }
        if let old = findSet(id: setID)?.set.proof { local.deleteProof(old) }
        let media = ProofMedia(kind: picked.kind, filename: filename)
        mutateSet(id: setID) { set in
            set.proof = media
            set.verification = .pending
        }
        changed()

        let fileURL = local.proofURL(for: media)
        Task {
            do {
                let status = try await backend.submitProof(setID: setID, fileURL: fileURL, kind: media.kind)
                self.applyVerification(status, to: setID)
                // Check back once the review is likely to have happened.
                try await Task.sleep(nanoseconds: 7_000_000_000)
                await self.refreshPendingVerifications()
            } catch {
                // Stays pending; retried on the next launch or foreground.
            }
        }
    }

    func removeProof(fromSet setID: UUID) {
        if let proof = findSet(id: setID)?.set.proof { local.deleteProof(proof) }
        mutateSet(id: setID) { set in
            set.proof = nil
            set.verification = .unverified
        }
        changed()
    }

    func proofURL(for media: ProofMedia) -> URL { local.proofURL(for: media) }

    private func applyVerification(_ status: VerificationStatus, to setID: UUID) {
        guard findSet(id: setID)?.set.verification != status else { return }
        mutateSet(id: setID) { $0.verification = status }
        changed()
    }

    func refreshPendingVerifications() async {
        let pending = allSessions.flatMap { $0.entries.flatMap(\.sets) }.filter { $0.verification == .pending }
        for set in pending {
            if let status = try? await backend.verificationStatus(setID: set.id), status != .pending {
                applyVerification(status, to: set.id)
            }
        }
    }

    // MARK: - Leaderboards & community

    func leaderboard(for query: LeaderboardQuery) async -> [LeaderboardRow] {
        let community: [LiftRecord]
        if let cached = communityCache[query.exerciseID] {
            community = cached
        } else {
            community = (try? await backend.fetchCommunityRecords(exerciseID: query.exerciseID)) ?? []
            communityCache[query.exerciseID] = community
        }
        let mine = myRecords.filter { $0.exerciseID == query.exerciseID }
        return LeaderboardEngine.rank(records: community + mine, query: query, currentUserID: profile?.id)
    }

    func clearCommunityCache() { communityCache.removeAll() }

    func flag(_ record: LiftRecord, reason: FlagReason) async {
        try? await backend.flag(recordID: record.id, reason: reason)
    }

    func lifterProfile(id: UUID) async -> PublicLifterProfile? {
        try? await backend.fetchLifterProfile(id: id)
    }

    func lifterProgress(id: UUID, exerciseID: String) async -> [ProgressPoint]? {
        guard let gymID = profile?.gymID else { return nil }
        return try? await backend.fetchLifterProgress(id: id, exerciseID: exerciseID, viewerGymID: gymID)
    }

    /// Whether the viewer can see a lifter's body stats or progress under the given setting.
    func canView(_ visibility: Audience, ownerGymID: String) -> Bool {
        switch visibility {
        case .everyone: return true
        case .gymMembers: return ownerGymID == profile?.gymID
        case .onlyMe: return false
        }
    }

    // MARK: - Housekeeping

    func resetAllData() {
        local.reset()
        profile = nil
        sessions = []
        activeSession = nil
        bodyMetrics = []
        communityCache = [:]
        dataVersion += 1
    }

    private func loadGyms() async {
        if let fetched = try? await backend.fetchGyms(), !fetched.isEmpty { gyms = fetched }
    }

    private func changed() {
        dataVersion += 1
        persist()
        sync()
    }

    private func persist() {
        local.save(AppData(profile: profile, sessions: sessions, activeSession: activeSession, bodyMetrics: bodyMetrics))
    }

    private func sync() {
        let records = myRecords
        guard !records.isEmpty else { return }
        Task { try? await backend.publish(records: records) }
    }
}
