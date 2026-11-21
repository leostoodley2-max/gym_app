import SwiftUI

struct PlateCalculatorView: View {
    @Environment(AppStore.self) private var store
    @State private var target: Double = 100
    @State private var barKg: Double = 20

    private var targetKg: Double { store.unit.toKg(target) }

    var body: some View {
        let result = PlateCalculator.plates(forTotal: targetKg, barKg: barKg)
        Form {
            Section {
                WeightStepper(weight: $target, step: store.unit == .kg ? 2.5 : 5, unit: store.unit,
                              label: "Total on the bar (\(store.unit.symbol))")
                    .padding(.vertical, 8)
                Picker("Bar", selection: $barKg) {
                    Text("20 kg Olympic").tag(20.0)
                    Text("15 kg women's").tag(15.0)
                    Text("10 kg technique").tag(10.0)
                }
            }
            Section("Each side") {
                if result.platesPerSide.isEmpty {
                    Text("Just the bar").foregroundStyle(.secondary)
                } else {
                    BarbellDiagram(plates: result.platesPerSide)
                        .frame(height: 120)
                        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    Text(result.platesPerSide.map { Format.weight($0, .kg) }.joined(separator: " + "))
                        .font(.subheadline.monospacedDigit())
                }
                if !result.isExact {
                    Label("Closest you can load is \(Format.weight(result.achievedKg, store.unit)).",
                          systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            }
        }
        .darkList()
        .navigationTitle("PLATE CALCULATOR")
    }
}

struct BarbellDiagram: View {
    let plates: [Double]

    private func color(for plate: Double) -> Color {
        switch plate {
        case 25: return .red
        case 20: return .blue
        case 15: return .yellow
        case 10: return .green
        case 5: return .white
        default: return .gray
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Rectangle().fill(Color.gray.opacity(0.6)).frame(width: 40, height: 10)
            Rectangle().fill(Color.gray).frame(width: 8, height: 30)
            ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(for: plate))
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.black.opacity(0.3)))
                    .frame(width: plate >= 10 ? 16 : 10, height: max(30, min(110, plate * 4.4)))
            }
            Rectangle().fill(Color.gray.opacity(0.6)).frame(width: 20, height: 10)
            Spacer()
        }
        .accessibilityLabel("Plates per side: \(plates.map { Format.weight($0, .kg) }.joined(separator: ", "))")
    }
}

struct OneRepMaxCalculatorView: View {
    @Environment(AppStore.self) private var store
    @State private var weight: Double = 100
    @State private var reps = 5

    var body: some View {
        let unit = store.unit
        let oneRM = StrengthCalculator.estimatedOneRepMax(load: unit.toKg(weight), reps: reps)
        Form {
            Section {
                WeightStepper(weight: $weight, step: unit == .kg ? 2.5 : 5, unit: unit, label: unit.symbol)
                    .padding(.vertical, 8)
                Stepper("\(reps) reps", value: $reps, in: 1...StrengthCalculator.maxRankableReps)
            }
            Section("Estimated one-rep max") {
                Text(Format.weight(oneRM, unit))
                    .font(.display(48))
                    .foregroundStyle(Theme.accent)
                if let profile = store.profile, profile.bodyweightKg > 0 {
                    LabeledContent("Pound for pound",
                                   value: Format.ratio(StrengthCalculator.relativeStrength(oneRepMaxKg: oneRM,
                                                                                           bodyweightKg: profile.bodyweightKg)))
                }
            }
            Section {
                ForEach([1, 2, 3, 5, 8, 10, 12], id: \.self) { targetReps in
                    LabeledContent("\(targetReps) rep\(targetReps == 1 ? "" : "s")",
                                   value: Format.weight(StrengthCalculator.weightFor(reps: targetReps, oneRepMaxKg: oneRM), unit))
                }
            } header: {
                Text("Rep targets")
            } footer: {
                Text("Epley formula below 10 reps, Brzycki from 10. Use these as working-weight targets.")
            }
        }
        .darkList()
        .navigationTitle("1RM CALCULATOR")
    }
}

struct HowRankingWorksView: View {
    var body: some View {
        List {
            Section("Scores") {
                Text("Every set from 1 to 12 reps gets an **estimated one-rep max** (e1RM): Epley below 10 reps, Brzycki from 10. Your best e1RM for each exercise is your leaderboard entry.")
                Text("**Heaviest** ranks the raw e1RM. **Pound for pound** divides it by your bodyweight on the day of the lift, so lighter lifters can top the board.")
                Text("Weighted pull-ups and dips count bodyweight plus added weight. Dumbbell lifts are ranked by the weight of one dumbbell.")
            }
            Section("Boards") {
                Text("**My Gym** ranks members of your home gym on the **honour system**: every lift you log counts straight away, no evidence needed. Partner gyms show this board live on their screens.")
                Text("**National** shows the **top \(LeaderboardEngine.nationalListSize)** lifters in the UK. Only lifts with approved video evidence appear. If your best lift would make the top \(LeaderboardEngine.nationalListSize), LiftBros shows your provisional position and asks you to upload evidence.")
                Text("Filter by division (Open, Men, Women) and by all time or this month's season.")
            }
            Section("Tiers") {
                ForEach(StrengthTier.allCases, id: \.self) { tier in
                    HStack {
                        TierBadge(tier: tier)
                        Spacer()
                        Text(tierDescription(tier)).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text("Tiers come from your e1RM ÷ bodyweight against standards for each exercise, adjusted by sex.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Evidence") {
                Label("Unverified: counts at your gym; not shown nationally.", systemImage: VerificationStatus.unverified.symbol)
                Label("Pending: evidence uploaded and in review.", systemImage: VerificationStatus.pending.symbol)
                    .foregroundStyle(VerificationStatus.pending.color)
                Label("Verified: approved, and eligible for the national top \(LeaderboardEngine.nationalListSize).", systemImage: VerificationStatus.verified.symbol)
                    .foregroundStyle(VerificationStatus.verified.color)
                Text("Good evidence is one continuous video showing the plates or weight stack, your full body and every rep. Free accounts get \(PlanLimits.freeEvidenceUploadsPerMonth) evidence uploads a month; Pro is unlimited with priority review. Anyone can report a suspicious lift, and lifts reported several times are hidden until evidence is provided.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .darkList()
        .navigationTitle("How it works")
    }

    private func tierDescription(_ tier: StrengthTier) -> String {
        switch tier {
        case .bronze: return "Starting out"
        case .silver: return "Novice"
        case .gold: return "Solid regular"
        case .platinum: return "Intermediate+"
        case .diamond: return "Advanced"
        case .elite: return "Competitive"
        }
    }
}
