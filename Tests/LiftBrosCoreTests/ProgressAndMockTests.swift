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
        let expected = MockCommunity.gyms.reduce(0) { $0 + MockCommunity.memberCount(for: $1, scale: 10) }
        XCTAssertEqual(a.lifters.count, expected)
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
        let submitted = try await backend.submitProof(setID: setID, fileURL: URL(fileURLWithPath: "/tmp/x.mov"),
                                                      kind: .video, priority: false)
        XCTAssertEqual(submitted, .pending)
        let reviewed = try await backend.verificationStatus(setID: setID)
        XCTAssertEqual(reviewed, .verified)
    }

    func testPendingProofSurvivesBackendRestart() async throws {
        // A fresh backend doesn't know about proof submitted before an app relaunch; it must not drop to unverified.
        let backend = MockBackendService(seed: 1, reviewDelay: 3600)
        let status = try await backend.verificationStatus(setID: UUID())
        XCTAssertEqual(status, .pending)
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

final class PlansAndGymsTests: XCTestCase {
    func testGymDirectoryIsWorcestershireWithUniqueIDs() {
        let gyms = WorcestershireGyms.all
        XCTAssertGreaterThan(gyms.count, 50)
        XCTAssertEqual(Set(gyms.map(\.id)).count, gyms.count)
        for district in District.allCases {
            XCTAssertTrue(gyms.contains { $0.district == district }, "no gyms in \(district)")
        }
        XCTAssertTrue(gyms.contains { $0.id == "puregym-worcester" })
    }

    func testEvidenceQuota() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        func set(uploadedDaysAgo days: Double) -> LiftSet {
            LiftSet(weightKg: 100, reps: 1, bodyweightKg: 80,
                    proof: ProofMedia(kind: .video, filename: "x.mov", uploadedAt: now.addingTimeInterval(-days * 86_400)),
                    verification: .pending)
        }
        let session = WorkoutSession(title: "S", gymID: "g", entries: [
            ExerciseEntry(exerciseID: "bench-press", sets: [set(uploadedDaysAgo: 1), set(uploadedDaysAgo: 2),
                                                           set(uploadedDaysAgo: 60), LiftSet(weightKg: 1, reps: 1, bodyweightKg: 80)]),
        ])
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        let used = PlanLimits.evidenceUploadsThisMonth(in: [session], now: now, calendar: calendar)
        XCTAssertEqual(used, 2)
        XCTAssertTrue(PlanLimits.canUploadEvidence(isPro: false, usedThisMonth: 2))
        XCTAssertFalse(PlanLimits.canUploadEvidence(isPro: false, usedThisMonth: PlanLimits.freeEvidenceUploadsPerMonth))
        XCTAssertTrue(PlanLimits.canUploadEvidence(isPro: true, usedThisMonth: 99))
    }

    func testFreeHistoryWindow() {
        let now = Date()
        let points = [ProgressPoint(date: now.addingTimeInterval(-200 * 86_400), value: 1),
                      ProgressPoint(date: now.addingTimeInterval(-7 * 86_400), value: 2)]
        XCTAssertEqual(PlanLimits.visibleHistory(points, isPro: false, now: now).map(\.value), [2])
        XCTAssertEqual(PlanLimits.visibleHistory(points, isPro: true, now: now).count, 2)
    }

    func testScreenPairingAndChallenges() async throws {
        let backend = MockBackendService(seed: 1)
        let paired = try await backend.pairScreen(code: "worc 2026")
        XCTAssertEqual(paired?.gymID, "puregym-worcester")
        XCTAssertNotNil(paired?.activeChallenge())
        let none = try await backend.pairScreen(code: "NOPE-0000")
        XCTAssertNil(none)
        let basic = try await backend.fetchPartnership(gymID: "wyreside-barbell")
        XCTAssertEqual(basic?.tier, .screen)
        XCTAssertNil(basic?.activeChallenge(), "Screen tier doesn't include challenges")
        for partnership in MockCommunity.samplePartnerships() {
            XCTAssertNotNil(MockCommunity.gyms.first { $0.id == partnership.gymID }, partnership.gymID)
        }
    }

    func testPriorityReviewIsFaster() async throws {
        let backend = MockBackendService(seed: 1, reviewDelay: 1.2)
        let normal = UUID(), priority = UUID()
        _ = try await backend.submitProof(setID: normal, fileURL: URL(fileURLWithPath: "/tmp/a"), kind: .video, priority: false)
        _ = try await backend.submitProof(setID: priority, fileURL: URL(fileURLWithPath: "/tmp/b"), kind: .video, priority: true)
        try await Task.sleep(nanoseconds: 600_000_000)
        let normalStatus = try await backend.verificationStatus(setID: normal)
        let priorityStatus = try await backend.verificationStatus(setID: priority)
        XCTAssertEqual(normalStatus, .pending)
        XCTAssertEqual(priorityStatus, .verified)
    }
}
