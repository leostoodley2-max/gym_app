import Foundation

public enum PlateCalculator {
    /// Standard UK commercial gym plates in kg.
    public static let defaultPlatesKg: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    public struct Result: Hashable, Sendable {
        /// Plates for ONE side of the bar, heaviest first.
        public let platesPerSide: [Double]
        /// The total actually achievable with these plates.
        public let achievedKg: Double
        public var isExact: Bool { remainderKg < 0.001 }
        public let remainderKg: Double
    }

    public static func plates(forTotal targetKg: Double, barKg: Double = 20,
                              available: [Double] = defaultPlatesKg) -> Result {
        guard targetKg > barKg else {
            return Result(platesPerSide: [], achievedKg: barKg, remainderKg: max(0, targetKg - barKg))
        }
        var perSide = (targetKg - barKg) / 2
        var plates: [Double] = []
        for plate in available.sorted(by: >) {
            while perSide + 0.0001 >= plate {
                plates.append(plate)
                perSide -= plate
            }
        }
        let achieved = barKg + plates.reduce(0, +) * 2
        return Result(platesPerSide: plates, achievedKg: achieved, remainderKg: max(0, targetKg - achieved))
    }
}
