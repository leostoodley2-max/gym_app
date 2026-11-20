import XCTest
@testable import LiftBrosCore

final class LeaderboardEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private func record(_ name: String, lifter: UUID = UUID(), gym: String = "gym-a", sex: Sex = .male,
                        exercise: String = "bench-press", weight: Double, reps: Int = 1, bodyweight: Double = 80,
                        daysAgo: Double = 1, verification: VerificationStatus = .unverified) -> LiftRecord {
        LiftRecord(lifterID: lifter, displayName: name, username: name.lowercased(), gymID: gym, sex: sex,
                   exerciseID: exercise, weightKg: weight, reps: reps, bodyweightKg: bodyweight,
                   performedAt: now.addingTimeInterval(-daysAgo * 86_400), verification: verification)
    }

    private func rank(_ records: [LiftRecord], _ query: LeaderboardQuery, user: UUID? = nil) -> [LeaderboardRow] {
        LeaderboardEngine.rank(records: records, query: query, currentUserID: user, now: now, calendar: calendar)
    }

    func testRanksByEstimatedOneRepMaxAndKeepsBestPerLifter() {
        let alice = UUID()
        let records = [
            record("Alice", lifter: alice, weight: 100, reps: 1),
            record("Alice", lifter: alice, weight: 100, reps: 5),   // e1RM 116.7 — her best
            record("Bob", weight: 110, reps: 1),
            record("Cara", weight: 90, reps: 3),                   // e1RM 99
        ]
        let rows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom), user: alice)
        XCTAssertEqual(rows.map(\.record.displayName), ["Alice", "Bob", "Cara"])
        XCTAssertEqual(rows.map(\.rank), [1, 2, 3])
        XCTAssertEqual(rows[0].record.reps, 5)
        XCTAssertTrue(rows[0].isCurrentUser)
        XCTAssertFalse(rows[1].isCurrentUser)
    }

    func testGymScopeFiltersOtherGyms() {
        let records = [record("Local", gym: "gym-a", weight: 100), record("Away", gym: "gym-b", weight: 200)]
        let gymRows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .gym("gym-a")))
        XCTAssertEqual(gymRows.map(\.record.displayName), ["Local"])
        let ukRows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom))
        XCTAssertEqual(ukRows.map(\.record.displayName), ["Away", "Local"])
    }

    func testRelativeMetricUsesBodyweight() {
        let records = [
            record("Heavy", weight: 150, bodyweight: 120),  // 1.25×
            record("Light", weight: 110, bodyweight: 70),   // 1.57×
        ]
        let absolute = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, metric: .absolute))
        XCTAssertEqual(absolute.first?.record.displayName, "Heavy")
        let relative = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, metric: .relative))
        XCTAssertEqual(relative.first?.record.displayName, "Light")
        XCTAssertEqual(relative.first?.score ?? 0, 110.0 / 70.0, accuracy: 0.0001)
    }

    func testVerifiedOnlyAndUnverifiedBothRankByDefault() {
        let records = [
            record("Unverified", weight: 150, verification: .unverified),
            record("Verified", weight: 120, verification: .verified),
            record("Pending", weight: 130, verification: .pending),
        ]
        let all = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom))
        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all.first?.record.verification, .unverified)
        let verifiedOnly = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, verifiedOnly: true))
        XCTAssertEqual(verifiedOnly.map(\.record.displayName), ["Verified"])
    }

    func testVerifiedOnlyFallsBackToLiftersBestVerifiedSet() {
        let lifter = UUID()
        let records = [
            record("Dan", lifter: lifter, weight: 160, verification: .unverified),
            record("Dan", lifter: lifter, weight: 140, verification: .verified),
        ]
        let rows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, verifiedOnly: true))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].record.weightKg, 140)
    }

    func testTiesShareRankAndVerifiedSortsFirst() {
        let records = [
            record("A", weight: 100, verification: .unverified),
            record("B", weight: 100, verification: .verified),
            record("C", weight: 90),
        ]
        let rows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom))
        XCTAssertEqual(rows.map(\.rank), [1, 1, 3])
        XCTAssertEqual(rows.first?.record.displayName, "B")
    }

    func testDivisionsAndHighRepSetsExcluded() {
        let records = [
            record("Man", sex: .male, weight: 100),
            record("Woman", sex: .female, weight: 70),
            record("Unspecified", sex: .preferNotToSay, weight: 80),
            record("Endurance", weight: 60, reps: 20),
        ]
        let women = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, division: .women))
        XCTAssertEqual(women.map(\.record.displayName), ["Woman"])
        let open = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom))
        XCTAssertEqual(Set(open.map(\.record.displayName)), ["Man", "Woman", "Unspecified"])
    }

    func testSeasonTimeframe() {
        let records = [record("Recent", weight: 100, daysAgo: 0), record("Old", weight: 200, daysAgo: 90)]
        let rows = rank(records, LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom, timeframe: .thisSeason))
        XCTAssertEqual(rows.map(\.record.displayName), ["Recent"])
    }

    func testRecordsFromSessionsSkipWarmupsAndDowngradeRejected() {
        let profile = UserProfile(displayName: "Me", username: "me", gymID: "gym-a", sex: .male, bodyweightKg: 80)
        let session = WorkoutSession(title: "Test", gymID: "gym-a", entries: [
            ExerciseEntry(exerciseID: "bench-press", sets: [
                LiftSet(weightKg: 60, reps: 10, bodyweightKg: 80, isWarmup: true),
                LiftSet(weightKg: 100, reps: 3, bodyweightKg: 80, verification: .rejected),
            ]),
        ])
        let records = LeaderboardEngine.records(from: [session], profile: profile)
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].verification, .unverified)
        XCTAssertEqual(records[0].lifterID, profile.id)
    }

    func testRepeatedlyFlaggedUnverifiedLiftsAreHidden() {
        var flagged = record("Sus", weight: 300)
        flagged.flagCount = LeaderboardEngine.flagHideThreshold
        var flaggedButVerified = record("Proven", weight: 250, verification: .verified)
        flaggedButVerified.flagCount = 10
        let rows = rank([flagged, flaggedButVerified, record("Normal", weight: 100)],
                        LeaderboardQuery(exerciseID: "bench-press", scope: .unitedKingdom))
        XCTAssertEqual(rows.map(\.record.displayName), ["Proven", "Normal"])
    }

    func testPercentile() {
        XCTAssertEqual(LeaderboardEngine.percentile(rank: 1, of: 100), 100)
        XCTAssertEqual(LeaderboardEngine.percentile(rank: 100, of: 100), 0)
        XCTAssertEqual(LeaderboardEngine.percentile(rank: 1, of: 1), 100)
    }
}
