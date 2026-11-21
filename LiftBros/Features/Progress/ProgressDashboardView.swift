import Charts
import SwiftUI

struct ProgressDashboardView: View {
    @Binding var showPaywall: Bool

    @Environment(AppStore.self) private var store
    @State private var exerciseID: String?
    @State private var showLogBodyweight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top) {
                        ScreenTitle(title: "Progress", subtitle: "Your strength")
                        CircleIconButton(systemImage: "scalemass.fill") { showLogBodyweight = true }
                            .accessibilityLabel("Log bodyweight")
                            .padding(.top, 14)
                    }
                    visibilityPicker
                    if store.allSessions.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "chart.xyaxis.line").font(.system(size: 40)).foregroundStyle(Theme.accent)
                            Text("Nothing to chart yet").font(.headline)
                            Text("Log your first workout and your strength progress appears here.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .card()
                    } else {
                        stats
                        strengthChart
                        personalBests
                        volumeChart
                    }
                    bodyweightChart
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 100)   // clear the floating tab bar
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
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

    private var visibilityPicker: some View {
        HStack {
            Image(systemName: store.profile?.privacy.progressVisibility == .onlyMe ? "lock.fill" : "eye.fill")
                .foregroundStyle(Theme.onAccent)
                .frame(width: 32, height: 32)
                .background(Theme.lavender, in: Circle())
            Text("Who can see your progress")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Picker("Visible to", selection: Binding(
                get: { store.profile?.privacy.progressVisibility ?? .everyone },
                set: { newValue in store.updateProfile { $0.privacy.progressVisibility = newValue } })) {
                ForEach(Audience.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .tint(Theme.accent)
        }
        .card(padding: 10, radius: 20)
    }

    private var stats: some View {
        let sessions = store.finishedSessions
        let totalVolume = sessions.reduce(0) { $0 + $1.totalVolumeKg }
        let verified = store.allSessions.flatMap(\.workingSets).filter { $0.verification == .verified }.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(title: "Workouts", value: "\(sessions.count)", systemImage: "figure.strengthtraining.traditional")
            StatTile(title: "Week streak", value: "\(ProgressAnalyzer.weeklyStreak(sessions: sessions))",
                     systemImage: "flame.fill", tint: Theme.orange)
            StatTile(title: "Total volume", value: Format.volume(totalVolume, store.unit), systemImage: "scalemass.fill",
                     tint: Theme.lavender)
            StatTile(title: "Verified sets", value: "\(verified)", systemImage: "checkmark.seal.fill", tint: Theme.teal)
        }
    }

    @ViewBuilder private var strengthChart: some View {
        if let exerciseID, let exercise = ExerciseLibrary.exercise(id: exerciseID), let profile = store.profile {
            let fullHistory = ProgressAnalyzer.oneRepMaxHistory(exerciseID: exerciseID, in: store.allSessions)
            let history = PlanLimits.visibleHistory(fullHistory, isPro: store.isPro)
            let hiddenCount = fullHistory.count - history.count
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
                    VStack(alignment: .leading, spacing: 0) {
                        Text("BEST e1RM").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
                        Text(Format.weight(best.estimatedOneRepMaxKg, store.unit)).font(.display(40))
                    }
                }
                Chart {
                    ForEach(history) { point in
                        AreaMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                        LineMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                        PointMark(x: .value("Date", point.date), y: .value("e1RM", store.unit.fromKg(point.value)))
                            .foregroundStyle(Theme.accent)
                            .symbolSize(30)
                    }
                    if let nextTarget, let next = tier?.next {
                        RuleMark(y: .value("Next tier", store.unit.fromKg(nextTarget)))
                            .foregroundStyle(next.color)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("\(next.displayName.uppercased()) \(Format.weight(nextTarget, store.unit))")
                                    .font(.caption2.weight(.heavy))
                                    .foregroundStyle(next.color)
                            }
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                if hiddenCount > 0 {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("\(hiddenCount) older sessions hidden. See all-time progress with Pro.", systemImage: "crown.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .card()
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
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "Personal bests")
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
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Format.weight(best.estimatedOneRepMaxKg, store.unit))
                                .font(.stat(16).monospacedDigit())
                            Text(Format.ratio(StrengthCalculator.relativeStrength(oneRepMaxKg: best.estimatedOneRepMaxKg,
                                                                                  bodyweightKg: best.set.bodyweightKg)))
                                .font(.caption2)
                                .foregroundStyle(Theme.secondaryText)
                        }
                        if let exercise {
                            TierBadge(tier: StrengthCalculator.tier(oneRepMaxKg: best.estimatedOneRepMaxKg,
                                                                    bodyweightKg: best.set.bodyweightKg,
                                                                    exercise: exercise, sex: profile.sex),
                                      compact: true)
                        }
                    }
                    .card(padding: 12, radius: 18)
                }
            }
        }
    }

    @ViewBuilder private var volumeChart: some View {
        let weekly = Array(ProgressAnalyzer.weeklyVolume(in: store.finishedSessions).suffix(8))
        if !weekly.isEmpty {
            let bars: [HighlightBarChart.Bar] = weekly.indices.map { index in
                HighlightBarChart.Bar(id: index, label: weekly[index].date.formatted(.dateTime.day()),
                                      value: weekly[index].value, isHighlighted: index == weekly.count - 1)
            }
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("WEEKLY VOLUME").font(.display(20))
                    Spacer()
                    if let last = weekly.last {
                        Text(Format.volume(last.value, store.unit)).font(.stat(17))
                    }
                }
                HighlightBarChart(bars: bars, height: 120, highlight: Theme.lavender)
            }
            .card()
        }
    }

    @ViewBuilder private var bodyweightChart: some View {
        if !store.bodyMetrics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("BODYWEIGHT").font(.display(20))
                    Spacer()
                    if let latest = store.bodyMetrics.last {
                        Text(Format.weight(latest.bodyweightKg, store.unit)).font(.stat(17))
                    }
                }
                if store.bodyMetrics.count > 1 {
                    Chart(store.bodyMetrics) { entry in
                        LineMark(x: .value("Date", entry.date), y: .value("Bodyweight", store.unit.fromKg(entry.bodyweightKg)))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Theme.pink)
                            .lineStyle(StrokeStyle(lineWidth: 3))
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 140)
                } else {
                    Text("Log your bodyweight regularly to see the trend. Pound-for-pound scores use your bodyweight on the day of each lift.")
                        .font(.footnote)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .card()
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
            .darkList()
            .navigationTitle("LOG BODYWEIGHT")
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
