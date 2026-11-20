import XCTest
@testable import LiftBrosCore

final class ProgressAnalyzerTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func session(daysAgo: Double, exercise: String = "bench-press", sets: [(Double, Int)]) -> WorkoutSession {
        let date = now.addingTimeInterval(-daysAgo * 86_400)
        return WorkoutSession(title: "S", gymID: "g", startedAt: date, endedAt: date.addingTimeInterval(3600), entries: [
            ExerciseEntry(exerciseID: exercise, sets: sets.map {
                LiftSet(weightKg: $0.0, reps: $0.1, performedAt: date, bodyweightKg: 80)
            }),
        ])
    }

    func testPersonalBestsUseEstimatedOneRepMax() {
        let sessions = [session(daysAgo: 10, sets: [(100, 1)]), session(daysAgo: 3, sets: [(90, 8)])]
        let best = ProgressAnalyzer.personalBests(in: sessions)["bench-press"]
        XCTAssertEqual(best?.set.weightKg, 90) // 90 × 8 ≈ 114 e1RM beats a 100 single
    }

    func testPersonalRecordDetection() {
        let old = session(daysAgo: 10, sets: [(100, 1)])
        let newer = session(daysAgo: 1, sets: [(105, 1)])
        let sessions = [old, newer]
        XCTAssertTrue(ProgressAnalyzer.isPersonalRecord(newer.entries[0].sets[0], exerciseID: "bench-press", in: sessions))
        let weaker = session(daysAgo: 0, sets: [(95, 1)])
        XCTAssertFalse(ProgressAnalyzer.isPersonalRecord(weaker.entries[0].sets[0], exerciseID: "bench-press",
                                                         in: sessions + [weaker]))
    }

    func testHistoryIsSortedOneEntryPerDay() {
        let sessions = [session(daysAgo: 1, sets: [(100, 1), (105, 1)]), session(daysAgo: 7, sets: [(90, 1)])]
        let history = ProgressAnalyzer.oneRepMaxHistory(exerciseID: "bench-press", in: sessions, calendar: calendar)
        XCTAssertEqual(history.map(\.value), [90, 105])
    }

    func testWeeklyStreak() {
        let sessions = [session(daysAgo: 0, sets: [(100, 1)]), session(daysAgo: 7, sets: [(100, 1)]),
                        session(daysAgo: 14, sets: [(100, 1)]), session(daysAgo: 35, sets: [(100, 1)])]
        XCTAssertEqual(ProgressAnalyzer.weeklyStreak(sessions: sessions, now: now, calendar: calendar), 3)
        XCTAssertEqual(ProgressAnalyzer.weeklyStreak(sessions: [], now: now, calendar: calendar), 0)
    }

    func testVolumeDoublesPerHandDumbbells() {
        let db = session(daysAgo: 0, exercise: "dumbbell-bench-press", sets: [(30, 10)])
        XCTAssertEqual(db.totalVolumeKg, 600)
        let bb = session(daysAgo: 0, sets: [(100, 5)])
        XCTAssertEqual(bb.totalVolumeKg, 500)
    }
}

final class MockCommunityTests: XCTestCase {
    func testGenerationIsDeterministicAndPlausible() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let a = MockCommunity.generate(seed: 7, liftersPerGym: 10, now: now)
        let b = MockCommunity.generate(seed: 7, liftersPerGym: 10, now: now)
        XCTAssertEqual(a.records, b.records)
        XCTAssertEqual(a.lifters.count, MockCommunity.gyms.count * 10)
        XCTAssertEqual(Set(a.lifters.map(\.username)).count, a.lifters.count, "usernames must be unique")

        let benches = a.records.filter { $0.exerciseID == "bench-press" }
        XCTAssertFalse(benches.isEmpty)
        for record in benches {
            let ratio = StrengthCalculator.estimatedOneRepMax(for: record) / record.bodyweightKg
            XCTAssertLessThan(ratio, 3.0, "bench ratio should be human")
            XCTAssertGreaterThanOrEqual(record.weightKg, 0)
        }
        XCTAssertTrue(a.records.contains { $0.verification == .verified })
        XCTAssertTrue(a.records.contains { $0.verification == .unverified })
    }

    func testRatioCurveIsMonotonic() {
        let thresholds = [0.5, 0.75, 1.0, 1.5, 2.0]
        var previous = -1.0
        for step in 0...55 {
            let ratio = MockCommunity.ratioAt(level: Double(step) / 10, thresholds: thresholds)
            XCTAssertGreaterThan(ratio, previous)
            previous = ratio
        }
        XCTAssertEqual(MockCommunity.ratioAt(level: 3, thresholds: thresholds), 1.0, accuracy: 0.0001)
    }

    func testMockBackendVerificationFlow() async throws {
        let backend = MockBackendService(seed: 1, reviewDelay: 0)
        let setID = UUID()
        let unverified = try await backend.verificationStatus(setID: setID)
        XCTAssertEqual(unverified, .unverified)
        let submitted = try await backend.submitProof(setID: setID, fileURL: URL(fileURLWithPath: "/tmp/x.mov"), kind: .video)
        XCTAssertEqual(submitted, .pending)
        let reviewed = try await backend.verificationStatus(setID: setID)
        XCTAssertEqual(reviewed, .verified)
    }

    func testPrivateProgressIsHidden() async throws {
        let backend = MockBackendService(seed: 3)
        let community = MockCommunity.generate(seed: 3)
        guard let privateLifter = community.lifters.first(where: { $0.progressVisibility == .onlyMe }) else {
            return XCTFail("expected at least one private lifter")
        }
        let progress = try await backend.fetchLifterProgress(id: privateLifter.id, exerciseID: "bench-press",
                                                             viewerGymID: privateLifter.gymID)
        XCTAssertNil(progress)
    }

    func testLocalStoreRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = LocalStore(directory: dir)
        let profile = UserProfile(displayName: "Me", username: "me", gymID: "g", sex: .female, bodyweightKg: 61.5,
                                  bodyFatPercent: 22)
        let data = AppData(profile: profile, sessions: [WorkoutSession(title: "Leg day", gymID: "g")],
                           bodyMetrics: [BodyMetricEntry(bodyweightKg: 61.5)])
        store.save(data)
        let loaded = store.load()
        XCTAssertEqual(loaded.profile, profile)
        XCTAssertEqual(loaded.sessions.first?.title, "Leg day")
        XCTAssertEqual(loaded.bodyMetrics.count, 1)
        try? FileManager.default.removeItem(at: dir)
    }
}
