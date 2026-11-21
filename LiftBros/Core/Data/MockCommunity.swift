import Foundation

/// Deterministic pseudo-random generator, so the demo community is identical on every launch.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

    /// Standard normal sample (Box–Muller).
    public mutating func gaussian(mean: Double = 0, sd: Double = 1) -> Double {
        let u1 = max(unit(), .leastNonzeroMagnitude)
        let u2 = unit()
        return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }

    public mutating func chance(_ p: Double) -> Bool { unit() < p }

    public mutating func pick<T>(_ items: [T]) -> T { items[Int(next() % UInt64(items.count))] }

    public mutating func uuid() -> UUID {
        let a = next(), b = next()
        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 { bytes[i] = UInt8(truncatingIfNeeded: a >> (8 * UInt64(i))) }
        for i in 0..<8 { bytes[8 + i] = UInt8(truncatingIfNeeded: b >> (8 * UInt64(i))) }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}

public struct MockLifter: Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let username: String
    public let gymID: String
    public let sex: Sex
    public let bodyweightKg: Double
    public let bodyFatPercent: Double?
    public let yearsLifting: Double
    public let progressVisibility: Audience
    public let bodyStatsVisibility: Audience
}

/// Generates a sample lifting community at real Worcestershire gyms for demos, previews and tests.
/// The people are fictional: the app labels them as sample data until a live backend is connected.
public enum MockCommunity {
    public static let gyms: [Gym] = WorcestershireGyms.all

    private static let maleNames = ["Jack", "Harry", "Oliver", "George", "Charlie", "Alfie", "Callum", "Ryan", "Kieran",
                                    "Liam", "Mo", "Arjun", "Tom", "Josh", "Dan", "Ben", "Sam", "Jamie", "Rhys", "Euan",
                                    "Connor", "Aaron", "Kofi", "Luca", "Nathan", "Owen", "Reece", "Tyler", "Zain", "Finn"]
    private static let femaleNames = ["Olivia", "Amelia", "Isla", "Ava", "Grace", "Freya", "Lily", "Sophie", "Megan",
                                      "Chloe", "Priya", "Aisha", "Ellie", "Hannah", "Niamh", "Caitlin", "Zara", "Ruby",
                                      "Jess", "Holly"]
    private static let surnames = ["Smith", "Jones", "Taylor", "Brown", "Williams", "Wilson", "Evans", "Thomas", "Roberts",
                                   "Walker", "Wright", "Patel", "Khan", "Hughes", "Edwards", "Green", "Hall", "Wood",
                                   "Clarke", "Murphy", "Campbell", "Stewart", "Kelly", "Ali", "Begum", "Morgan", "Shaw",
                                   "Price", "Mensah", "O'Neill"]

    public struct Community: Sendable {
        public let lifters: [MockLifter]
        public let records: [LiftRecord]
    }

    /// Sample members per gym, roughly by gym size.
    static func memberCount(for gym: Gym, scale: Int) -> Int {
        let base: Int
        switch gym.kind {
        case .chain, .leisure: base = 28
        case .strength: base = 20
        case .independent, .crossfit: base = 14
        case .college, .healthClub: base = 8
        }
        return max(1, base * scale / 24)
    }

    /// - Parameter liftersPerGym: scale factor; 24 gives the default gym sizes.
    public static func generate(seed: UInt64 = 2026, liftersPerGym: Int = 24, now: Date = Date()) -> Community {
        var rng = SeededGenerator(seed: seed)
        var lifters: [MockLifter] = []
        var records: [LiftRecord] = []
        var usedUsernames = Set<String>()

        for gym in gyms {
            for _ in 0..<memberCount(for: gym, scale: liftersPerGym) {
                let isFemale = rng.chance(0.3)
                let sex: Sex = isFemale ? .female : .male
                let first = isFemale ? rng.pick(femaleNames) : rng.pick(maleNames)
                let last = rng.pick(surnames)
                var username = "\(first.lowercased())\(last.lowercased().filter(\.isLetter).prefix(3))"
                while usedUsernames.contains(username) { username += String(rng.next() % 10) }
                usedUsernames.insert(username)

                let bodyweight = isFemale
                    ? min(max(rng.gaussian(mean: 66, sd: 9), 48), 110)
                    : min(max(rng.gaussian(mean: 85, sd: 12), 58), 140)
                let years = min(max(rng.gaussian(mean: 3.5, sd: 2.5), 0.3), 15)
                let bodyFat: Double? = rng.chance(0.6)
                    ? (isFemale ? rng.gaussian(mean: 26, sd: 4) : rng.gaussian(mean: 17, sd: 4))
                    : nil
                // Training level on the 0–5 tier scale: experience helps, talent varies.
                let level = min(max(1.2 + years * 0.28 + rng.gaussian(sd: 0.7), 0.15), 5.4)

                let lifter = MockLifter(
                    id: rng.uuid(), displayName: "\(first) \(last)", username: username, gymID: gym.id, sex: sex,
                    bodyweightKg: (bodyweight * 10).rounded() / 10,
                    bodyFatPercent: bodyFat.map { (min(max($0, 6), 45) * 10).rounded() / 10 },
                    yearsLifting: (years * 2).rounded() / 2,
                    progressVisibility: rng.chance(0.7) ? .everyone : (rng.chance(0.5) ? .gymMembers : .onlyMe),
                    bodyStatsVisibility: rng.chance(0.4) ? .everyone : .onlyMe)
                lifters.append(lifter)

                let verifiedRate = rng.unit() * 0.8
                let isPro = rng.chance(0.15)
                for exercise in ExerciseLibrary.all {
                    let isFeatured = ExerciseLibrary.featuredIDs.contains(exercise.id)
                    guard rng.chance(isFeatured ? 0.85 : 0.45) else { continue }
                    let liftLevel = min(max(level + rng.gaussian(sd: 0.45), 0.05), 5.6)
                    let ratio = ratioAt(level: liftLevel, thresholds: exercise.standards.thresholds(for: sex))
                    let oneRepMax = ratio * lifter.bodyweightKg
                    let reps = rng.pick([1, 1, 2, 3, 3, 5, 5, 5, 6, 8, 8, 10])
                    var load = StrengthCalculator.weightFor(reps: reps, oneRepMaxKg: oneRepMax)
                    if exercise.addsBodyweight { load -= lifter.bodyweightKg }
                    let increment = exercise.incrementKg
                    let weight = max(0, (load / increment).rounded() * increment)
                    let daysAgo = Double(rng.next() % 150) + rng.unit()
                    let verification: VerificationStatus = rng.chance(verifiedRate)
                        ? .verified
                        : (rng.chance(0.08) ? .pending : .unverified)
                    records.append(LiftRecord(
                        id: rng.uuid(), lifterID: lifter.id, displayName: lifter.displayName, username: lifter.username,
                        gymID: gym.id, sex: sex, exerciseID: exercise.id, weightKg: weight, reps: reps,
                        bodyweightKg: lifter.bodyweightKg, performedAt: now.addingTimeInterval(-daysAgo * 86_400),
                        verification: verification, isPro: isPro))
                }
            }
        }
        return Community(lifters: lifters, records: records)
    }

    /// Maps a continuous level (0–5+) onto a bodyweight ratio using tier thresholds.
    static func ratioAt(level: Double, thresholds: [Double]) -> Double {
        // Anchor points: level 0 → 60% of the Silver threshold, level n → threshold n.
        let points = [thresholds[0] * 0.6] + thresholds
        if level >= 5 {
            let slope = points[5] - points[4]
            return points[5] + (level - 5) * slope
        }
        let lower = Int(level)
        let fraction = level - Double(lower)
        return points[lower] + (points[lower + 1] - points[lower]) * fraction
    }

    /// A plausible progress curve ending at the lifter's current best.
    public static func progressHistory(endingAt oneRepMax: Double, lifterID: UUID, exerciseID: String,
                                       now: Date = Date()) -> [ProgressPoint] {
        // Stable FNV-1a hash (Swift's hashValue is randomised per launch).
        var seed: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in (lifterID.uuidString + exerciseID).utf8 {
            seed = (seed ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        var rng = SeededGenerator(seed: seed)
        let weeks = 16
        let startFraction = 0.78 + rng.unit() * 0.1
        return (0..<weeks).map { week in
            let progress = Double(week) / Double(weeks - 1)
            let eased = 1 - pow(1 - progress, 2)
            let value = oneRepMax * (startFraction + (1 - startFraction) * eased) * (1 + rng.gaussian(sd: 0.012))
            let date = now.addingTimeInterval(-Double(weeks - 1 - week) * 7 * 86_400)
            return ProgressPoint(date: date, value: week == weeks - 1 ? oneRepMax : value)
        }
    }

    /// Sample gym partnerships so the in-gym screen can be demoed.
    public static func samplePartnerships(now: Date = Date(), calendar: Calendar = .current) -> [GymPartnership] {
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 30 * 86_400)
        return [
            GymPartnership(
                gymID: "puregym-worcester", tier: .screenPlus, status: .active, pairingCode: "WORC-2026",
                screen: ScreenConfig(accentHex: "D4FF3F"),
                challenge: GymChallenge(title: "December Bench Battle", exerciseID: "bench-press", metric: .relative,
                                        startsAt: month.start, endsAt: month.end, prize: "3 months free membership"),
                renewsAt: month.end),
            GymPartnership(gymID: "wyreside-barbell", tier: .screen, status: .trial, pairingCode: "WYRE-0001",
                           renewsAt: month.end),
            GymPartnership(
                gymID: "abbey-stadium-sports-fitness-centre", tier: .screenPlus, status: .active,
                pairingCode: "ABBY-7788",
                challenge: GymChallenge(title: "Squat Season", exerciseID: "back-squat", metric: .absolute,
                                        startsAt: month.start, endsAt: month.end, prize: "LiftBros hoodie"),
                renewsAt: month.end),
        ]
    }
}
