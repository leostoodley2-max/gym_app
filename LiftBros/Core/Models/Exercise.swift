import Foundation

public enum ExerciseCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case chest, back, legs, shoulders, arms

    public var displayName: String { rawValue.capitalized }
}

public enum Equipment: String, Codable, CaseIterable, Hashable, Sendable {
    case barbell, dumbbell, machine, cable, smithMachine, bodyweight

    public var displayName: String {
        switch self {
        case .barbell: return "Barbell"
        case .dumbbell: return "Dumbbell"
        case .machine: return "Machine"
        case .cable: return "Cable"
        case .smithMachine: return "Smith Machine"
        case .bodyweight: return "Bodyweight"
        }
    }
}

/// Bodyweight-ratio thresholds (estimated 1RM ÷ bodyweight) used to place a lift in a tier.
/// `thresholds` holds 5 ascending values for Silver, Gold, Platinum, Diamond and Elite (male standards).
/// Anything below the first threshold is Bronze. Female standards are scaled by `femaleFactor`.
public struct StrengthStandards: Codable, Hashable, Sendable {
    public let thresholds: [Double]
    public let femaleFactor: Double

    public init(_ thresholds: [Double], femaleFactor: Double) {
        precondition(thresholds.count == 5, "Standards need exactly 5 thresholds")
        self.thresholds = thresholds
        self.femaleFactor = femaleFactor
    }

    public func thresholds(for sex: Sex) -> [Double] {
        sex == .female ? thresholds.map { $0 * femaleFactor } : thresholds
    }
}

public struct Exercise: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let category: ExerciseCategory
    public let equipment: Equipment
    /// Dumbbell lifts are logged and ranked by the weight of one dumbbell.
    public let isPerHand: Bool
    /// Weighted pull-ups / dips: the load moved is bodyweight + added weight.
    public let addsBodyweight: Bool
    public let standards: StrengthStandards

    public init(id: String, name: String, category: ExerciseCategory, equipment: Equipment,
                isPerHand: Bool = false, addsBodyweight: Bool = false, standards: StrengthStandards) {
        self.id = id
        self.name = name
        self.category = category
        self.equipment = equipment
        self.isPerHand = isPerHand
        self.addsBodyweight = addsBodyweight
        self.standards = standards
    }

    /// Smallest sensible weight increment, used for rounding generated data and plate maths.
    public var incrementKg: Double {
        switch equipment {
        case .dumbbell: return 2
        case .machine, .cable: return 2.5
        default: return 2.5
        }
    }

    public var weightLabel: String {
        if isPerHand { return "kg per dumbbell" }
        if addsBodyweight { return "added kg" }
        return "kg"
    }
}

public enum ExerciseLibrary {
    private static let upper = 0.6
    private static let lower = 0.72

    public static let all: [Exercise] = [
        // Barbell
        Exercise(id: "bench-press", name: "Bench Press", category: .chest, equipment: .barbell,
                 standards: .init([0.5, 0.75, 1.0, 1.5, 2.0], femaleFactor: upper)),
        Exercise(id: "incline-bench-press", name: "Incline Bench Press", category: .chest, equipment: .barbell,
                 standards: .init([0.4, 0.65, 0.85, 1.25, 1.65], femaleFactor: upper)),
        Exercise(id: "back-squat", name: "Back Squat", category: .legs, equipment: .barbell,
                 standards: .init([0.75, 1.25, 1.5, 2.25, 2.75], femaleFactor: lower)),
        Exercise(id: "front-squat", name: "Front Squat", category: .legs, equipment: .barbell,
                 standards: .init([0.6, 1.0, 1.25, 1.75, 2.2], femaleFactor: lower)),
        Exercise(id: "deadlift", name: "Deadlift", category: .back, equipment: .barbell,
                 standards: .init([1.0, 1.5, 2.0, 2.5, 3.0], femaleFactor: lower)),
        Exercise(id: "romanian-deadlift", name: "Romanian Deadlift", category: .legs, equipment: .barbell,
                 standards: .init([0.75, 1.1, 1.5, 2.0, 2.5], femaleFactor: lower)),
        Exercise(id: "overhead-press", name: "Overhead Press", category: .shoulders, equipment: .barbell,
                 standards: .init([0.35, 0.55, 0.75, 1.0, 1.25], femaleFactor: upper)),
        Exercise(id: "barbell-row", name: "Barbell Row", category: .back, equipment: .barbell,
                 standards: .init([0.5, 0.75, 1.0, 1.4, 1.75], femaleFactor: upper)),
        Exercise(id: "hip-thrust", name: "Hip Thrust", category: .legs, equipment: .barbell,
                 standards: .init([0.75, 1.25, 1.75, 2.5, 3.25], femaleFactor: 0.85)),

        // Dumbbell (per hand)
        Exercise(id: "dumbbell-bench-press", name: "Dumbbell Bench Press", category: .chest, equipment: .dumbbell,
                 isPerHand: true, standards: .init([0.2, 0.3, 0.45, 0.6, 0.75], femaleFactor: upper)),
        Exercise(id: "dumbbell-shoulder-press", name: "Dumbbell Shoulder Press", category: .shoulders, equipment: .dumbbell,
                 isPerHand: true, standards: .init([0.15, 0.22, 0.32, 0.45, 0.55], femaleFactor: upper)),
        Exercise(id: "dumbbell-curl", name: "Dumbbell Curl", category: .arms, equipment: .dumbbell,
                 isPerHand: true, standards: .init([0.1, 0.15, 0.25, 0.35, 0.45], femaleFactor: upper)),

        // Machines & cables
        Exercise(id: "lat-pulldown", name: "Lat Pulldown", category: .back, equipment: .cable,
                 standards: .init([0.5, 0.75, 1.0, 1.25, 1.5], femaleFactor: 0.65)),
        Exercise(id: "seated-cable-row", name: "Seated Cable Row", category: .back, equipment: .cable,
                 standards: .init([0.5, 0.75, 1.0, 1.3, 1.6], femaleFactor: 0.65)),
        Exercise(id: "leg-press", name: "Leg Press", category: .legs, equipment: .machine,
                 standards: .init([1.5, 2.25, 3.0, 4.0, 5.0], femaleFactor: lower)),
        Exercise(id: "hack-squat", name: "Hack Squat", category: .legs, equipment: .machine,
                 standards: .init([0.75, 1.25, 1.75, 2.5, 3.0], femaleFactor: lower)),
        Exercise(id: "smith-machine-squat", name: "Smith Machine Squat", category: .legs, equipment: .smithMachine,
                 standards: .init([0.75, 1.2, 1.6, 2.2, 2.7], femaleFactor: lower)),
        Exercise(id: "leg-extension", name: "Leg Extension", category: .legs, equipment: .machine,
                 standards: .init([0.5, 0.8, 1.1, 1.5, 1.9], femaleFactor: lower)),
        Exercise(id: "seated-leg-curl", name: "Seated Leg Curl", category: .legs, equipment: .machine,
                 standards: .init([0.4, 0.6, 0.85, 1.15, 1.45], femaleFactor: lower)),
        Exercise(id: "calf-raise-machine", name: "Standing Calf Raise", category: .legs, equipment: .machine,
                 standards: .init([1.0, 1.5, 2.0, 2.75, 3.5], femaleFactor: lower)),
        Exercise(id: "chest-press-machine", name: "Chest Press Machine", category: .chest, equipment: .machine,
                 standards: .init([0.5, 0.8, 1.1, 1.5, 1.9], femaleFactor: upper)),
        Exercise(id: "pec-deck", name: "Pec Deck", category: .chest, equipment: .machine,
                 standards: .init([0.4, 0.65, 0.9, 1.25, 1.6], femaleFactor: upper)),
        Exercise(id: "shoulder-press-machine", name: "Shoulder Press Machine", category: .shoulders, equipment: .machine,
                 standards: .init([0.35, 0.55, 0.75, 1.0, 1.3], femaleFactor: upper)),
        Exercise(id: "tricep-pushdown", name: "Tricep Pushdown", category: .arms, equipment: .cable,
                 standards: .init([0.25, 0.4, 0.6, 0.85, 1.1], femaleFactor: upper)),

        // Bodyweight + load
        Exercise(id: "weighted-pull-up", name: "Weighted Pull-Up", category: .back, equipment: .bodyweight,
                 addsBodyweight: true, standards: .init([1.0, 1.15, 1.35, 1.6, 1.85], femaleFactor: 0.85)),
        Exercise(id: "weighted-dip", name: "Weighted Dip", category: .chest, equipment: .bodyweight,
                 addsBodyweight: true, standards: .init([1.05, 1.25, 1.5, 1.8, 2.1], femaleFactor: 0.85)),
    ]

    private static let byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func exercise(id: String) -> Exercise? { byID[id] }

    /// The headline lifts shown first in pickers.
    public static let featuredIDs = ["bench-press", "back-squat", "deadlift", "overhead-press", "lat-pulldown", "leg-press"]
}
