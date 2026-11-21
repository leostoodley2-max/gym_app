import Observation
import SwiftUI
import UIKit

enum AppTab: Hashable {
    case train, rankings, progress, profile
}

enum DemoScreen: String {
    case onboarding, train, workout, logSet, setDetail, rankingsGym, rankingsUK, rankingsP4P, lifter, progress, profile
    case paywall, gymScreen
}

/// Debug-only demo mode for screenshots and screen recordings.
///
/// Launch arguments (Debug builds only):
/// - `-LBDemo`: start with a seeded demo account in a throwaway data folder (your real data is untouched)
/// - `-LBScreen <name>`: jump straight to a screen (see `DemoScreen`)
/// - `-LBTour`: drive the app through its main screens automatically, for screen recordings
///
/// See `scripts/capture-screens.sh`.
@MainActor
@Observable
final class DemoDirector {
    static let shared = DemoDirector()

    let isEnabled: Bool
    let isTour: Bool
    let screen: DemoScreen?

    // State the views follow while demo mode is on.
    var tab: AppTab = .train
    var showActiveWorkout = false
    var logSetOpen = false
    var restTimerTick = 0
    var setToOpen: UUID?
    var leaderboardUK = false
    var leaderboardRelative = false
    var openTopLifterTick = 0
    var showPaywall = false
    var showGymScreen = false

    @ObservationIgnored private weak var store: AppStore?
    @ObservationIgnored private var benchEntryID: UUID?
    @ObservationIgnored private var verifiedSetID: UUID?
    @ObservationIgnored private var started = false

    private init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        isEnabled = args.contains("-LBDemo")
        isTour = args.contains("-LBTour")
        if let index = args.firstIndex(of: "-LBScreen"), index + 1 < args.count {
            screen = DemoScreen(rawValue: args[index + 1])
        } else {
            screen = nil
        }
        #else
        isEnabled = false
        isTour = false
        screen = nil
        #endif
    }

    func makeStore() -> AppStore {
        guard isEnabled else { return AppStore() }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("LiftBrosDemo", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        let store = AppStore(backend: MockBackendService(reviewDelay: 3600), local: LocalStore(directory: directory))
        store.subscriptions.setPreviewPro(false)
        self.store = store
        if screen != .onboarding { seed(store) }
        return store
    }

    func start() {
        guard isEnabled, !started else { return }
        started = true
        Task {
            if isTour {
                await runTour()
            } else if let screen {
                await apply(screen)
            }
        }
    }

    // MARK: - Screens

    private func apply(_ screen: DemoScreen) async {
        switch screen {
        case .onboarding, .train:
            tab = .train
        case .workout:
            await pause(0.6)
            showActiveWorkout = true
        case .logSet:
            await pause(0.6)
            showActiveWorkout = true
            await pause(1.2)
            logSetOpen = true
        case .setDetail:
            await pause(0.6)
            showActiveWorkout = true
            await pause(1.2)
            setToOpen = verifiedSetID
        case .rankingsGym:
            tab = .rankings
        case .rankingsUK:
            logDemoSet(startTimer: false)   // an unverified PR, so the national card asks for evidence
            leaderboardUK = true
            tab = .rankings
        case .rankingsP4P:
            leaderboardUK = true
            leaderboardRelative = true
            tab = .rankings
        case .lifter:
            leaderboardUK = true
            tab = .rankings
            await pause(2.0)
            openTopLifterTick += 1
        case .progress:
            tab = .progress
        case .profile:
            tab = .profile
        case .paywall:
            await pause(0.6)
            showPaywall = true
        case .gymScreen:
            await pause(0.6)
            showGymScreen = true
        }
    }

    private func runTour() async {
        await pause(4.0)                        // Home
        showActiveWorkout = true                // Workout in progress
        await pause(2.5)
        logSetOpen = true                       // Log a set
        await pause(3.0)
        logDemoSet()                            // Save → PR banner + rest timer
        await pause(3.5)
        showActiveWorkout = false
        await pause(1.0)
        withAnimation { tab = .rankings }       // Gym leaderboard (honour system)
        await pause(3.5)
        withAnimation { leaderboardUK = true }  // National: top 100, evidence needed
        await pause(3.5)
        withAnimation { leaderboardRelative = true } // Pound for pound
        await pause(2.5)
        openTopLifterTick += 1                  // Another lifter's profile
        await pause(3.0)
        withAnimation { tab = .progress }
        await pause(3.0)
        withAnimation { tab = .profile }
        await pause(2.5)
        showPaywall = true                      // LiftBros Pro
        await pause(3.0)
        showPaywall = false
        await pause(1.0)
        showGymScreen = true                    // In-gym leaderboard screen
    }

    private func logDemoSet(startTimer: Bool = true) {
        guard let store, let benchEntryID else { return }
        store.addSet(entryID: benchEntryID, weightKg: 122.5, reps: 5, rpe: 9, isWarmup: false)
        logSetOpen = false
        if startTimer { restTimerTick += 1 }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // MARK: - Demo data

    private struct PlannedLift {
        let id: String
        let start: Double
        let end: Double
        let reps: Int
        let sets: Int
        let step: Double
    }

    private func seed(_ store: AppStore) {
        let calendar = Calendar.current
        let now = Date()
        let day: TimeInterval = 86_400
        let weeks = 16
        let gymID = "puregym-worcester"
        let proofData = Self.proofImageData()

        func proof() -> ProofMedia? {
            guard let filename = try? store.local.saveProof(data: proofData, fileExtension: "jpg") else { return nil }
            return ProofMedia(kind: .photo, filename: filename)
        }

        let profile = UserProfile(
            displayName: "Alex Carter", username: "alexlifts", gymID: gymID, sex: .male,
            birthYear: calendar.component(.year, from: now) - 27, heightCm: 180, bodyweightKg: 82.5,
            bodyFatPercent: 14.5, yearsLifting: 4, trainingDaysPerWeek: 4, goal: .strength,
            bio: "Chasing a 220 kg deadlift.", createdAt: now.addingTimeInterval(-Double(weeks) * 7 * day))

        let push = [
            PlannedLift(id: "bench-press", start: 100, end: 120, reps: 5, sets: 3, step: 2.5),
            PlannedLift(id: "overhead-press", start: 55, end: 70, reps: 5, sets: 3, step: 2.5),
            PlannedLift(id: "dumbbell-bench-press", start: 30, end: 36, reps: 8, sets: 3, step: 2),
            PlannedLift(id: "tricep-pushdown", start: 30, end: 40, reps: 10, sets: 3, step: 2.5),
        ]
        let pull = [
            PlannedLift(id: "deadlift", start: 175, end: 210, reps: 3, sets: 2, step: 2.5),
            PlannedLift(id: "lat-pulldown", start: 65, end: 80, reps: 8, sets: 3, step: 2.5),
            PlannedLift(id: "seated-cable-row", start: 60, end: 75, reps: 10, sets: 3, step: 2.5),
            PlannedLift(id: "dumbbell-curl", start: 14, end: 18, reps: 10, sets: 3, step: 2),
        ]
        let legs = [
            PlannedLift(id: "back-squat", start: 135, end: 165, reps: 5, sets: 3, step: 2.5),
            PlannedLift(id: "leg-press", start: 180, end: 240, reps: 10, sets: 3, step: 5),
            PlannedLift(id: "leg-extension", start: 50, end: 65, reps: 12, sets: 3, step: 2.5),
            PlannedLift(id: "seated-leg-curl", start: 45, end: 55, reps: 12, sets: 3, step: 2.5),
        ]
        let program: [(title: String, dayOffset: Double, lifts: [PlannedLift])] = [
            ("Push Day", 0, push), ("Pull Day", 2, pull), ("Leg Day", 4, legs),
        ]
        let showcaseLifts: Set<String> = ["bench-press", "back-squat", "deadlift"]

        var sessions: [WorkoutSession] = []
        var metrics: [BodyMetricEntry] = []
        let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        for week in 0..<weeks {
            let fraction = Double(week) / Double(weeks - 1)
            let weekStart = thisWeek.addingTimeInterval(-Double(weeks - 1 - week) * 7 * day)
            let bodyweight = ((84.5 - 2.0 * fraction) * 10).rounded() / 10
            metrics.append(BodyMetricEntry(date: weekStart.addingTimeInterval(7 * 3600), bodyweightKg: bodyweight,
                                           bodyFatPercent: ((16.5 - 2.0 * fraction) * 10).rounded() / 10))

            for workout in program {
                let start = weekStart.addingTimeInterval(workout.dayOffset * day + 18 * 3600)
                guard start < now.addingTimeInterval(-3 * 3600) else { continue }
                var entries: [ExerciseEntry] = []
                for (liftIndex, lift) in workout.lifts.enumerated() {
                    let top = ((lift.start + (lift.end - lift.start) * fraction) / lift.step).rounded() * lift.step
                    let backOff = ((top * 0.9) / lift.step).rounded() * lift.step
                    var sets: [LiftSet] = []
                    var time = start.addingTimeInterval(Double(liftIndex) * 900)
                    if liftIndex == 0 {
                        sets.append(LiftSet(weightKg: ((top * 0.5) / lift.step).rounded() * lift.step, reps: 8,
                                            performedAt: time, bodyweightKg: bodyweight, isWarmup: true))
                        time += 180
                    }
                    for setIndex in 0..<lift.sets {
                        var set = LiftSet(weightKg: setIndex == 0 ? top : backOff, reps: lift.reps, performedAt: time,
                                          bodyweightKg: bodyweight)
                        if setIndex == 0 && showcaseLifts.contains(lift.id) {
                            if week == weeks - 1 && lift.id == "back-squat" {
                                set.proof = proof()
                                set.verification = .pending
                            } else if week >= weeks - 7 && week % 2 == 1 {
                                set.proof = proof()
                                set.verification = .verified
                            }
                        }
                        sets.append(set)
                        time += 180
                    }
                    entries.append(ExerciseEntry(exerciseID: lift.id, sets: sets))
                }
                sessions.append(WorkoutSession(title: workout.title, gymID: gymID, startedAt: start,
                                               endedAt: start.addingTimeInterval(65 * 60), entries: entries))
            }
        }

        // Today's workout, in progress.
        let activeStart = now.addingTimeInterval(-38 * 60)
        let verifiedSet = LiftSet(weightKg: 120, reps: 5, rpe: 8.5, performedAt: activeStart.addingTimeInterval(600),
                                  bodyweightKg: 82.5, proof: proof(), verification: .verified)
        let bench = ExerciseEntry(exerciseID: "bench-press", sets: [
            LiftSet(weightKg: 60, reps: 8, performedAt: activeStart.addingTimeInterval(300), bodyweightKg: 82.5, isWarmup: true),
            verifiedSet,
            LiftSet(weightKg: 120, reps: 5, rpe: 9, performedAt: activeStart.addingTimeInterval(800), bodyweightKg: 82.5),
        ])
        let press = ExerciseEntry(exerciseID: "overhead-press", sets: [
            LiftSet(weightKg: 70, reps: 5, performedAt: activeStart.addingTimeInterval(1500), bodyweightKg: 82.5),
            LiftSet(weightKg: 70, reps: 5, performedAt: activeStart.addingTimeInterval(1700), bodyweightKg: 82.5),
        ])
        benchEntryID = bench.id
        verifiedSetID = verifiedSet.id
        let active = WorkoutSession(title: "Push Day", gymID: gymID, startedAt: activeStart, entries: [bench, press])

        store.replaceAllData(AppData(profile: profile, sessions: sessions, activeSession: active, bodyMetrics: metrics))
    }

    /// A placeholder image standing in for a proof video.
    private static func proofImageData() -> Data {
        let content = ZStack {
            LinearGradient(colors: [Color(white: 0.22), Color(white: 0.06)], startPoint: .top, endPoint: .bottom)
            VStack(spacing: 28) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 260))
                    .foregroundStyle(.white)
                Text("Evidence: 120 kg × 5")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 960, height: 720)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 1
        return renderer.uiImage?.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
