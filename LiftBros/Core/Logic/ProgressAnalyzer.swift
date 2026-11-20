import Foundation

public struct ProgressPoint: Identifiable, Hashable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let value: Double
}

public struct PersonalBest: Identifiable, Hashable, Sendable {
    public var id: String { exerciseID }
    public let exerciseID: String
    public let set: LiftSet
    public let estimatedOneRepMaxKg: Double
}

public enum ProgressAnalyzer {
    /// Best set (by estimated 1RM) for every exercise the user has logged.
    public static func personalBests(in sessions: [WorkoutSession]) -> [String: PersonalBest] {
        var bests: [String: PersonalBest] = [:]
        for session in sessions {
            for entry in session.entries {
                let exercise = entry.exercise
                for set in entry.sets where !set.isWarmup && StrengthCalculator.isRankable(reps: set.reps) {
                    let e1rm = StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise)
                    if let current = bests[entry.exerciseID], current.estimatedOneRepMaxKg >= e1rm { continue }
                    bests[entry.exerciseID] = PersonalBest(exerciseID: entry.exerciseID, set: set, estimatedOneRepMaxKg: e1rm)
                }
            }
        }
        return bests
    }

    /// True if `set` beats every earlier rankable set of the same exercise.
    public static func isPersonalRecord(_ set: LiftSet, exerciseID: String, in sessions: [WorkoutSession]) -> Bool {
        guard !set.isWarmup, StrengthCalculator.isRankable(reps: set.reps) else { return false }
        let exercise = ExerciseLibrary.exercise(id: exerciseID)
        let target = StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise)
        for session in sessions {
            for entry in session.entries where entry.exerciseID == exerciseID {
                for other in entry.sets where other.id != set.id && !other.isWarmup
                    && StrengthCalculator.isRankable(reps: other.reps) && other.performedAt <= set.performedAt {
                    if StrengthCalculator.estimatedOneRepMax(for: other, exercise: exercise) >= target { return false }
                }
            }
        }
        return target > 0
    }

    /// Best estimated 1RM per calendar day for an exercise, oldest first.
    public static func oneRepMaxHistory(exerciseID: String, in sessions: [WorkoutSession],
                                        calendar: Calendar = .current) -> [ProgressPoint] {
        let exercise = ExerciseLibrary.exercise(id: exerciseID)
        var byDay: [Date: Double] = [:]
        for session in sessions {
            for entry in session.entries where entry.exerciseID == exerciseID {
                for set in entry.sets where !set.isWarmup && StrengthCalculator.isRankable(reps: set.reps) {
                    let day = calendar.startOfDay(for: set.performedAt)
                    byDay[day] = max(byDay[day] ?? 0, StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise))
                }
            }
        }
        return byDay.map { ProgressPoint(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    /// Total working volume (kg × reps) per week, oldest first.
    public static func weeklyVolume(in sessions: [WorkoutSession], calendar: Calendar = .current) -> [ProgressPoint] {
        var byWeek: [Date: Double] = [:]
        for session in sessions {
            guard let week = calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start else { continue }
            byWeek[week, default: 0] += session.totalVolumeKg
        }
        return byWeek.map { ProgressPoint(date: $0.key, value: $0.value) }.sorted { $0.date < $1.date }
    }

    /// Consecutive weeks (ending this week or last week) with at least one workout.
    public static func weeklyStreak(sessions: [WorkoutSession], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let weeks = Set(sessions.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start })
        guard var cursor = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        if !weeks.contains(cursor) {
            // The current week isn't over yet; a streak still counts if last week was trained.
            guard let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = lastWeek
        }
        var streak = 0
        while weeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    public static func workouts(in sessions: [WorkoutSession], thisWeekOf now: Date = Date(),
                                calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessions.filter { week.contains($0.startedAt) }.count
    }
}
