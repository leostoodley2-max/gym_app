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

enum EvidenceError: LocalizedError {
    case monthlyLimitReached

    var errorDescription: String? {
        "You've used your \(PlanLimits.freeEvidenceUploadsPerMonth) free evidence uploads this month. Upgrade to Pro for unlimited uploads."
    }
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
    /// The signed-in user's gym's screen subscription, if any.
    private(set) var currentPartnership: GymPartnership?
    /// Default rest between sets (customisable with Pro).
    private(set) var restSeconds: Int = UserDefaults.standard.object(forKey: "LiftBros.restSeconds") as? Int ?? 120

    @ObservationIgnored private var communityCache: [String: [LiftRecord]] = [:]
    @ObservationIgnored let backend: BackendService
    @ObservationIgnored let local: LocalStore
    @ObservationIgnored let subscriptions = SubscriptionManager()

    init(backend: BackendService = MockBackendService(), local: LocalStore = LocalStore()) {
        self.backend = backend
        self.local = local
        let data = local.load()
        profile = data.profile
        sessions = data.sessions
        activeSession = data.activeSession
        bodyMetrics = data.bodyMetrics
        Task {
            await loadGyms()
            await loadPartnership()
        }
    }

    // MARK: - Derived data

    var unit: WeightUnit { profile?.unit ?? .kg }

    var currentGym: Gym? { profile.flatMap { gym(id: $0.gymID) } }

    /// Existing users whose saved gym is no longer in the directory must pick again.
    var needsGymSelection: Bool { profile != nil && currentGym == nil }

    var isPro: Bool { subscriptions.isPro }

    /// True while running on the built-in sample community rather than a live server.
    var isUsingSampleData: Bool { backend is MockBackendService }

    var evidenceUploadsThisMonth: Int { PlanLimits.evidenceUploadsThisMonth(in: allSessions) }

    var canUploadEvidence: Bool {
        PlanLimits.canUploadEvidence(isPro: isPro, usedThisMonth: evidenceUploadsThisMonth)
    }

    var evidenceUploadsLeft: Int? {
        isPro ? nil : max(0, PlanLimits.freeEvidenceUploadsPerMonth - evidenceUploadsThisMonth)
    }

    func gym(id: String) -> Gym? { gyms.first { $0.id == id } }

    /// Finished sessions plus the one in progress, newest first.
    var allSessions: [WorkoutSession] {
        (sessions + [activeSession].compactMap { $0 }).sorted { $0.startedAt > $1.startedAt }
    }

    var finishedSessions: [WorkoutSession] { sessions.sorted { $0.startedAt > $1.startedAt } }

    var personalBests: [String: PersonalBest] { ProgressAnalyzer.personalBests(in: allSessions) }

    var myRecords: [LiftRecord] {
        guard let profile, profile.privacy.showOnLeaderboards else { return [] }
        let pro = isPro
        return LeaderboardEngine.records(from: allSessions, profile: profile).map { record in
            var record = record
            record.isPro = pro
            return record
        }
    }

    func setRestSeconds(_ seconds: Int) {
        restSeconds = seconds
        UserDefaults.standard.set(seconds, forKey: "LiftBros.restSeconds")
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

    func chooseGym(_ gymID: String) {
        updateProfile { $0.gymID = gymID }
        if activeSession != nil { activeSession?.gymID = gymID }
        Task { await loadPartnership() }
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
        let isReplacement = findSet(id: setID)?.set.proof != nil
        if !isReplacement && !canUploadEvidence { throw EvidenceError.monthlyLimitReached }
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
                let status = try await backend.submitProof(setID: setID, fileURL: fileURL, kind: media.kind,
                                                            priority: self.isPro)
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
        let community = await communityRecords(for: query.exerciseID)
        let mine = myRecords.filter { $0.exerciseID == query.exerciseID }
        return LeaderboardEngine.rank(records: community + mine, query: query, currentUserID: profile?.id)
    }

    func clearCommunityCache() { communityCache.removeAll() }

    private func communityRecords(for exerciseID: String) async -> [LiftRecord] {
        if let cached = communityCache[exerciseID] { return cached }
        let fetched = (try? await backend.fetchCommunityRecords(exerciseID: exerciseID)) ?? []
        communityCache[exerciseID] = fetched
        return fetched
    }

    func nationalStanding(for query: LeaderboardQuery) async -> NationalStanding {
        let community = await communityRecords(for: query.exerciseID)
        let mine = myRecords.filter { $0.exerciseID == query.exerciseID }
        return LeaderboardEngine.nationalStanding(records: community + mine, query: query, currentUserID: profile?.id)
    }

    /// Ranks for a gym's screen (honour system, everyone at that gym).
    func screenLeaderboard(gymID: String, exerciseID: String, metric: LeaderboardMetric,
                           since: Date? = nil) async -> [LeaderboardRow] {
        let community = await communityRecords(for: exerciseID)
        let mine = myRecords.filter { $0.exerciseID == exerciseID }
        var records = community + mine
        if let since { records = records.filter { $0.performedAt >= since } }
        return LeaderboardEngine.rank(records: records,
                                      query: LeaderboardQuery(exerciseID: exerciseID, scope: .gym(gymID), metric: metric),
                                      currentUserID: profile?.id)
    }

    // MARK: - Gym partnerships

    func loadPartnership() async {
        guard let gymID = profile?.gymID else {
            currentPartnership = nil
            return
        }
        currentPartnership = try? await backend.fetchPartnership(gymID: gymID)
    }

    func pairScreen(code: String) async -> GymPartnership? {
        try? await backend.pairScreen(code: code)
    }

    // MARK: - Export (Pro)

    /// Writes every logged set to a CSV file and returns its URL.
    func exportCSV() throws -> URL {
        var lines = ["date,workout,gym,exercise,weight_kg,reps,rpe,warmup,bodyweight_kg,e1rm_kg,verification"]
        let formatter = ISO8601DateFormatter()
        for session in allSessions.reversed() {
            let gymName = gym(id: session.gymID)?.name ?? session.gymID
            for entry in session.entries {
                let exercise = entry.exercise
                for set in entry.sets {
                    let e1rm = StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise)
                    let fields: [String] = [
                        formatter.string(from: set.performedAt), session.title, gymName, exercise?.name ?? entry.exerciseID,
                        String(set.weightKg), String(set.reps), set.rpe.map { String($0) } ?? "",
                        set.isWarmup ? "yes" : "no", String(set.bodyweightKg),
                        String((e1rm * 10).rounded() / 10), set.verification.rawValue,
                    ]
                    lines.append(fields.map { field in
                        field.contains(",") || field.contains("\"") ? "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\"" : field
                    }.joined(separator: ","))
                }
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LiftBros-export.csv")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

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

    /// Replaces everything in the store (used by demo mode).
    func replaceAllData(_ data: AppData) {
        profile = data.profile
        sessions = data.sessions
        activeSession = data.activeSession
        bodyMetrics = data.bodyMetrics
        communityCache = [:]
        changed()
    }

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
