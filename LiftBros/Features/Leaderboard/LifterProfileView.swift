import Charts
import SwiftUI

struct LifterProfileView: View {
    let lifterID: UUID

    @Environment(AppStore.self) private var store
    @State private var profile: PublicLifterProfile?
    @State private var isLoading = true
    @State private var selectedExerciseID: String?
    @State private var progress: [ProgressPoint]?
    @State private var progressLoaded = false

    var body: some View {
        Group {
            if let profile {
                content(profile)
            } else if isLoading {
                ProgressView()
            } else {
                ContentUnavailableView("Lifter not found", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
        .navigationTitle(profile?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            profile = await store.lifterProfile(id: lifterID)
            isLoading = false
            selectedExerciseID = sortedBests.first?.exerciseID
        }
        .task(id: selectedExerciseID) {
            guard let selectedExerciseID else { return }
            progressLoaded = false
            progress = await store.lifterProgress(id: lifterID, exerciseID: selectedExerciseID)
            progressLoaded = true
        }
    }

    private var sortedBests: [LiftRecord] {
        guard let profile else { return [] }
        let featured = ExerciseLibrary.featuredIDs
        var best: [String: LiftRecord] = [:]
        for record in profile.bestLifts {
            if let existing = best[record.exerciseID],
               StrengthCalculator.estimatedOneRepMax(for: existing) >= StrengthCalculator.estimatedOneRepMax(for: record) {
                continue
            }
            best[record.exerciseID] = record
        }
        return best.values.sorted {
            let l = featured.firstIndex(of: $0.exerciseID) ?? Int.max
            let r = featured.firstIndex(of: $1.exerciseID) ?? Int.max
            return l != r ? l < r : $0.exerciseID < $1.exerciseID
        }
    }

    private func content(_ profile: PublicLifterProfile) -> some View {
        List {
            Section {
                HStack(spacing: 16) {
                    AvatarView(name: profile.displayName, size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.displayName).font(.title3.weight(.bold))
                        Text("@\(profile.username)").foregroundStyle(.secondary)
                        if let gym = store.gym(id: profile.gymID) {
                            Label(gym.name, systemImage: "mappin.and.ellipse").font(.caption)
                        }
                    }
                }
                LabeledContent("Lifting for", value: yearsLabel(profile.yearsLifting))
                LabeledContent("Bodyweight", value: Format.weight(profile.bodyweightKg, store.unit))
                if store.canView(profile.bodyStatsVisibility, ownerGymID: profile.gymID) {
                    if let bodyFat = profile.bodyFatPercent {
                        LabeledContent("Body fat", value: "\(bodyFat.formatted(.number.precision(.fractionLength(0...1))))%")
                    }
                } else {
                    Label("Other body stats are private", systemImage: "lock.fill")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Progress") {
                if store.canView(profile.progressVisibility, ownerGymID: profile.gymID) {
                    if let selectedExerciseID {
                        ExerciseMenu(selection: Binding(get: { selectedExerciseID }, set: { self.selectedExerciseID = $0 }),
                                     exerciseIDs: sortedBests.map(\.exerciseID))
                    }
                    if let progress, !progress.isEmpty {
                        Chart(progress) { point in
                            LineMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                                .interpolationMethod(.catmullRom)
                            PointMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                                .symbolSize(20)
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 180)
                    } else if !progressLoaded {
                        ProgressView()
                    }
                } else {
                    Label(profile.progressVisibility == .gymMembers
                          ? "Only members of their gym can see this progress."
                          : "This lifter keeps their progress private.",
                          systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Best lifts") {
                ForEach(sortedBests) { record in
                    let exercise = ExerciseLibrary.exercise(id: record.exerciseID)
                    let oneRM = StrengthCalculator.estimatedOneRepMax(for: record)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(exercise?.name ?? record.exerciseID).font(.subheadline.weight(.semibold))
                                VerificationBadge(status: record.verification, showsLabel: false)
                            }
                            Text("\(Format.record(record, unit: store.unit)) · \(Format.shortDate(record.performedAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Format.weight(oneRM, store.unit)).font(.subheadline.weight(.bold).monospacedDigit())
                            if let exercise {
                                TierBadge(tier: StrengthCalculator.tier(oneRepMaxKg: oneRM, bodyweightKg: record.bodyweightKg,
                                                                        exercise: exercise, sex: record.sex),
                                          compact: true)
                            }
                        }
                    }
                }
            }
        }
    }
}
