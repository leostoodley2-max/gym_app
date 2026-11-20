import XCTest
@testable import LiftBrosCore

final class StrengthCalculatorTests: XCTestCase {
    func testSingleRepIsTheLoad() {
        XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: 140, reps: 1), 140)
    }

    func testEpleyBelowTenReps() {
        XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: 100, reps: 5), 100 * (1 + 5.0 / 30), accuracy: 0.001)
    }

    func testBrzyckiFromTenReps() {
        XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: 100, reps: 10), 100 * 36 / 27, accuracy: 0.001)
    }

    func testZeroRepsOrLoadIsZero() {
        XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: 100, reps: 0), 0)
        XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: 0, reps: 5), 0)
    }

    func testWeightForRepsInvertsOneRepMax() {
        for reps in [1, 3, 5, 8, 10, 12] {
            let oneRM = 150.0
            let weight = StrengthCalculator.weightFor(reps: reps, oneRepMaxKg: oneRM)
            XCTAssertEqual(StrengthCalculator.estimatedOneRepMax(load: weight, reps: reps), oneRM, accuracy: 0.001,
                           "reps \(reps)")
        }
    }

    func testWeightedPullUpIncludesBodyweight() {
        let pullUp = ExerciseLibrary.exercise(id: "weighted-pull-up")!
        XCTAssertEqual(StrengthCalculator.effectiveLoad(weightKg: 20, bodyweightKg: 80, exercise: pullUp), 100)
        let bench = ExerciseLibrary.exercise(id: "bench-press")!
        XCTAssertEqual(StrengthCalculator.effectiveLoad(weightKg: 20, bodyweightKg: 80, exercise: bench), 20)
    }

    func testTiers() {
        let bench = ExerciseLibrary.exercise(id: "bench-press")!
        XCTAssertEqual(StrengthCalculator.tier(ratio: 0.3, exercise: bench, sex: .male), .bronze)
        XCTAssertEqual(StrengthCalculator.tier(ratio: 0.5, exercise: bench, sex: .male), .silver)
        XCTAssertEqual(StrengthCalculator.tier(ratio: 1.0, exercise: bench, sex: .male), .platinum)
        XCTAssertEqual(StrengthCalculator.tier(ratio: 2.1, exercise: bench, sex: .male), .elite)
        // Female standards are scaled down: 0.6 × 1.0 = 0.6 reaches Platinum.
        XCTAssertEqual(StrengthCalculator.tier(ratio: 0.6, exercise: bench, sex: .female), .platinum)
    }

    func testNextTierTarget() {
        let squat = ExerciseLibrary.exercise(id: "back-squat")!
        let target = StrengthCalculator.oneRepMaxForNextTier(currentTier: .gold, bodyweightKg: 80, exercise: squat, sex: .male)
        XCTAssertEqual(target ?? 0, 120, accuracy: 0.001) // Platinum threshold 1.5 × 80
        XCTAssertNil(StrengthCalculator.oneRepMaxForNextTier(currentTier: .elite, bodyweightKg: 80, exercise: squat, sex: .male))
    }

    func testLibraryHasUniqueIDsAndValidStandards() {
        let ids = ExerciseLibrary.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        for exercise in ExerciseLibrary.all {
            XCTAssertEqual(exercise.standards.thresholds, exercise.standards.thresholds.sorted(), exercise.id)
        }
        for id in ExerciseLibrary.featuredIDs { XCTAssertNotNil(ExerciseLibrary.exercise(id: id)) }
    }

    func testUnitConversion() {
        XCTAssertEqual(WeightUnit.lb.fromKg(100), 220.462, accuracy: 0.01)
        XCTAssertEqual(WeightUnit.lb.toKg(WeightUnit.lb.fromKg(87.5)), 87.5, accuracy: 0.0001)
        XCTAssertEqual(WeightUnit.kg.fromKg(50), 50)
    }

    func testPlateCalculator() {
        let result = PlateCalculator.plates(forTotal: 142.5)
        XCTAssertEqual(result.platesPerSide, [25, 25, 10, 1.25])
        XCTAssertTrue(result.isExact)
        let odd = PlateCalculator.plates(forTotal: 101)
        XCTAssertEqual(odd.achievedKg, 100)
        XCTAssertFalse(odd.isExact)
        XCTAssertEqual(PlateCalculator.plates(forTotal: 20).platesPerSide, [])
    }
}
