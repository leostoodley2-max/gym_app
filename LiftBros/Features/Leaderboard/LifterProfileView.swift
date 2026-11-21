import Charts
import SwiftUI

struct LifterProfileView: View {
    let lifterID: UUID
    @Binding var showPaywall: Bool

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(profile)
                progressCard(profile)
                headToHead
                bestLifts
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 100)
        }
    }

    private func header(_ profile: PublicLifterProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                AvatarView(name: profile.displayName, size: 68)
                VStack(alignment: .leading, spacing: 3) {
                    Text(profile.displayName.uppercased()).font(.display(28))
                    Text("@\(profile.username)").font(.subheadline).foregroundStyle(Theme.secondaryText)
                    if let gym = store.gym(id: profile.gymID) { GymCaption(name: gym.name) }
                }
            }
            HStack(spacing: 8) {
                StatTile(title: "Lifting", value: yearsLabel(profile.yearsLifting), systemImage: "calendar", tint: Theme.lavender)
                StatTile(title: "Bodyweight", value: Format.weight(profile.bodyweightKg, store.unit),
                         systemImage: "scalemass.fill", tint: Theme.teal)
                if store.canView(profile.bodyStatsVisibility, ownerGymID: profile.gymID), let bodyFat = profile.bodyFatPercent {
                    StatTile(title: "Body fat", value: "\(bodyFat.formatted(.number.precision(.fractionLength(0...1))))%",
                             systemImage: "drop.fill", tint: Theme.pink)
                } else {
                    StatTile(title: "Body stats", value: "Private", systemImage: "lock.fill", tint: Theme.secondaryText)
                }
            }
        }
    }

    private func progressCard(_ profile: PublicLifterProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("PROGRESS").font(.display(20))
                Spacer()
                if let selectedExerciseID, store.canView(profile.progressVisibility, ownerGymID: profile.gymID) {
                    ExerciseMenu(selection: Binding(get: { selectedExerciseID }, set: { self.selectedExerciseID = $0 }),
                                 exerciseIDs: sortedBests.map(\.exerciseID))
                }
            }
            if store.canView(profile.progressVisibility, ownerGymID: profile.gymID) {
                if let progress, !progress.isEmpty {
                    Chart(progress) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 170)
                } else if !progressLoaded {
                    ProgressView().frame(maxWidth: .infinity)
                }
            } else {
                Label(profile.progressVisibility == .gymMembers
                      ? "Only members of their gym can see this progress."
                      : "This lifter keeps their progress private.",
                      systemImage: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .card()
    }

    @ViewBuilder private var headToHead: some View {
        let mine = store.personalBests
        let shared = sortedBests.filter { mine[$0.exerciseID] != nil }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("HEAD TO HEAD").font(.display(20))
                Spacer()
                ProBadge()
            }
            if !store.isPro {
                Text("Compare your best lifts against \(profile?.displayName.split(separator: " ").first.map(String.init) ?? "this lifter"), lift by lift.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                Button("Unlock with Pro") { showPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            } else if shared.isEmpty {
                Text("You haven't logged any of the same lifts yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            } else {
                ForEach(shared) { theirs in
                    let myBest = mine[theirs.exerciseID]?.estimatedOneRepMaxKg ?? 0
                    let theirBest = StrengthCalculator.estimatedOneRepMax(for: theirs)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ExerciseLibrary.exercise(id: theirs.exerciseID)?.name ?? theirs.exerciseID)
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Text("You \(Format.weight(myBest, store.unit))")
                                .foregroundStyle(myBest >= theirBest ? Theme.accent : .white)
                            Spacer()
                            Text("Them \(Format.weight(theirBest, store.unit))")
                                .foregroundStyle(theirBest > myBest ? Theme.lavender : .white)
                        }
                        .font(.caption.weight(.bold))
                        GeometryReader { geo in
                            let total = max(myBest + theirBest, 1)
                            HStack(spacing: 3) {
                                Capsule().fill(Theme.accent).frame(width: geo.size.width * myBest / total)
                                Capsule().fill(Theme.lavender)
                            }
                        }
                        .frame(height: 8)
                    }
                }
            }
        }
        .card()
    }

    private var bestLifts: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Best lifts")
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
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Format.weight(oneRM, store.unit)).font(.stat(16).monospacedDigit())
                        if let exercise {
                            TierBadge(tier: StrengthCalculator.tier(oneRepMaxKg: oneRM, bodyweightKg: record.bodyweightKg,
                                                                    exercise: exercise, sex: record.sex),
                                      compact: true)
                        }
                    }
                }
                .card(padding: 12, radius: 18)
            }
        }
    }
}
