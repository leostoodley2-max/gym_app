import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Environment(AppStore.self) private var store
    @State private var exerciseID: String?
    @State private var showLogBodyweight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    visibilityBanner
                    if store.allSessions.isEmpty {
                        ContentUnavailableView("Nothing to chart yet", systemImage: "chart.xyaxis.line",
                                               description: Text("Log your first workout and your strength progress will appear here."))
                    } else {
                        stats
                        strengthChart
                        personalBests
                        volumeChart
                    }
                    bodyweightChart
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLogBodyweight = true
                    } label: {
                        Label("Log bodyweight", systemImage: "scalemass")
                    }
                }
            }
            .sheet(isPresented: $showLogBodyweight) {
                LogBodyMetricView()
            }
            .onAppear {
                if exerciseID == nil || !store.loggedExerciseIDs.contains(exerciseID ?? "") {
                    exerciseID = ExerciseLibrary.featuredIDs.first(where: { store.loggedExerciseIDs.contains($0) })
                        ?? store.loggedExerciseIDs.first
                }
            }
        }
    }

    private var visibilityBanner: some View {
        HStack {
            Image(systemName: store.profile?.privacy.progressVisibility == .onlyMe ? "lock.fill" : "eye.fill")
                .foregroundStyle(Theme.accent)
            Text("Visible to")
                .font(.subheadline)
            Spacer()
            Picker("Visible to", selection: Binding(
                get: { store.profile?.privacy.progressVisibility ?? .everyone },
                set: { newValue in store.updateProfile { $0.privacy.progressVisibility = newValue } })) {
                ForEach(Audience.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var stats: some View {
        let sessions = store.finishedSessions
        let totalVolume = sessions.reduce(0) { $0 + $1.totalVolumeKg }
        let verified = store.allSessions.flatMap(\.workingSets).filter { $0.verification == .verified }.count
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Workouts", value: "\(sessions.count)", systemImage: "figure.strengthtraining.traditional")
            StatTile(title: "Week streak", value: "\(ProgressAnalyzer.weeklyStreak(sessions: sessions))",
                     systemImage: "flame.fill", tint: .orange)
            StatTile(title: "Total volume", value: Format.volume(totalVolume, store.unit), systemImage: "scalemass.fill",
                     tint: .blue)
            StatTile(title: "Verified lifts", value: "\(verified)", systemImage: "checkmark.seal.fill", tint: .green)
        }
    }

    @ViewBuilder private var strengthChart: some View {
        if let exerciseID, let exercise = ExerciseLibrary.exercise(id: exerciseID), let profile = store.profile {
            let history = ProgressAnalyzer.oneRepMaxHistory(exerciseID: exerciseID, in: store.allSessions)
            let best = store.personalBests[exerciseID]
            let tier = best.map {
                StrengthCalculator.tier(oneRepMaxKg: $0.estimatedOneRepMaxKg, bodyweightKg: profile.bodyweightKg,
                                        exercise: exercise, sex: profile.sex)
            }
            let nextTarget = tier.flatMap {
                StrengthCalculator.oneRepMaxForNextTier(currentTier: $0, bodyweightKg: profile.bodyweightKg,
                                                        exercise: exercise, sex: profile.sex)
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ExerciseMenu(selection: Binding(get: { exerciseID }, set: { self.exerciseID = $0 }),
                                 exerciseIDs: store.loggedExerciseIDs)
                    Spacer()
                    if let tier { TierBadge(tier: tier) }
                }
                if let best {
                    Text("Best e1RM \(Format.weight(best.estimatedOneRepMaxKg, store.unit))")
                        .font(.title2.weight(.bold))
                }
                Chart {
                    ForEach(history) { point in
                        LineMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accent)
                        PointMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .foregroundStyle(Theme.accent)
                    }
                    if let nextTarget, let next = tier?.next {
                        RuleMark(y: .value("Next tier", store.unit.fromKg(nextTarget)))
                            .foregroundStyle(next.color)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("\(next.displayName) \(Format.weight(nextTarget, store.unit))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(next.color)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
            }
            .padding()
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder private var personalBests: some View {
        let bests = store.personalBests.values.sorted { lhs, rhs in
            let featured = ExerciseLibrary.featuredIDs
            let l = featured.firstIndex(of: lhs.exerciseID) ?? Int.max
            let r = featured.firstIndex(of: rhs.exerciseID) ?? Int.max
            return l != r ? l < r : lhs.exerciseID < rhs.exerciseID
        }
        if !bests.isEmpty, let profile = store.profile {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal bests").font(.title3.weight(.bold))
                ForEach(bests) { best in
                    let exercise = ExerciseLibrary.exercise(id: best.exerciseID)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 4) {
                                Text(exercise?.name ?? best.exerciseID).font(.subheadline.weight(.semibold))
                                VerificationBadge(status: best.set.verification, showsLabel: false)
                            }
                            Text("\(Format.liftSet(best.set, exercise: exercise, unit: store.unit)) · \(Format.shortDate(best.set.performedAt))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Format.weight(best.estimatedOneRepMaxKg, store.unit))
                                .font(.subheadline.weight(.bold).monospacedDigit())
                            Text(Format.ratio(StrengthCalculator.relativeStrength(oneRepMaxKg: best.estimatedOneRepMaxKg,
                                                                                  bodyweightKg: best.set.bodyweightKg)))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if let exercise {
                            TierBadge(tier: StrengthCalculator.tier(oneRepMaxKg: best.estimatedOneRepMaxKg,
                                                                    bodyweightKg: best.set.bodyweightKg,
                                                                    exercise: exercise, sex: profile.sex),
                                      compact: true)
                        }
                    }
                    Divider()
                }
            }
            .padding()
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder private var volumeChart: some View {
        let weekly = ProgressAnalyzer.weeklyVolume(in: store.finishedSessions).suffix(12)
        if !weekly.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly volume").font(.title3.weight(.bold))
                Chart(Array(weekly)) { point in
                    BarMark(x: .value("Week", point.date, unit: .weekOfYear),
                            y: .value("Volume", store.unit.fromKg(point.value)))
                        .foregroundStyle(Color.blue.gradient)
                }
                .frame(height: 160)
            }
            .padding()
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    @ViewBuilder private var bodyweightChart: some View {
        if !store.bodyMetrics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Bodyweight").font(.title3.weight(.bold))
                    Spacer()
                    if let latest = store.bodyMetrics.last {
                        Text(Format.weight(latest.bodyweightKg, store.unit)).font(.headline)
                    }
                }
                if store.bodyMetrics.count > 1 {
                    Chart(store.bodyMetrics) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Bodyweight", store.unit.fromKg(entry.bodyweightKg)))
                            .foregroundStyle(.purple)
                        PointMark(x: .value("Date", entry.date), y: .value("Bodyweight", store.unit.fromKg(entry.bodyweightKg)))
                            .foregroundStyle(.purple)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 160)
                } else {
                    Text("Log your bodyweight regularly to see the trend. Your pound-for-pound score uses your bodyweight on the day of each lift.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct LogBodyMetricView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var bodyweight: Double?
    @State private var bodyFat: Double?
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                DecimalField(title: "Bodyweight", value: $bodyweight, suffix: store.unit.symbol, prompt: "Required")
                DecimalField(title: "Body fat", value: $bodyFat, suffix: "%", prompt: "Optional")
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
            }
            .navigationTitle("Log bodyweight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let bodyweight {
                            store.logBodyMetric(bodyweightKg: store.unit.toKg(bodyweight), bodyFatPercent: bodyFat, date: date)
                        }
                        dismiss()
                    }
                    .disabled(!(30...300).contains(store.unit.toKg(bodyweight ?? 0)))
                }
            }
            .onAppear {
                if bodyweight == nil, let current = store.profile?.bodyweightKg {
                    bodyweight = (store.unit.fromKg(current) * 10).rounded() / 10
                }
            }
        }
        .presentationDetents([.medium])
    }
}
