import SwiftUI

struct ActiveWorkoutView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var showExercisePicker = false
    @State private var logTarget: ExerciseEntry?
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var restTimer = RestTimer()
    @State private var path: [UUID] = []
    private let demo = DemoDirector.shared

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if let session = store.activeSession {
                    workoutList(session)
                } else {
                    ContentUnavailableView("No active workout", systemImage: "dumbbell")
                }
            }
            .navigationTitle(store.activeSession?.title ?? "Workout")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { setID in
                SetDetailView(setID: setID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("Minimise workout")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Finish workout", systemImage: "checkmark") { confirmFinish = true }
                        Button("Discard workout", systemImage: "trash", role: .destructive) { confirmDiscard = true }
                    } label: {
                        Text("Finish").fontWeight(.semibold)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                RestTimerBar(timer: restTimer)
            }
            .overlay(alignment: .top) {
                if let pr = store.prCelebration {
                    PRBanner(celebration: pr, unit: store.unit)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .task(id: pr.id) {
                            try? await Task.sleep(nanoseconds: 3_500_000_000)
                            withAnimation { store.prCelebration = nil }
                        }
                }
            }
            .animation(.spring, value: store.prCelebration)
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView { exerciseID in
                    store.addExercise(exerciseID)
                }
            }
            .sheet(item: $logTarget) { entry in
                LogSetView(entryID: entry.id, exerciseID: entry.exerciseID) { isWarmup in
                    restTimer.start(seconds: isWarmup ? 60 : restTimer.defaultSeconds)
                }
            }
            .onChange(of: demo.logSetOpen) { _, open in
                guard demo.isEnabled else { return }
                logTarget = open ? store.activeSession?.entries.first : nil
            }
            .onChange(of: demo.restTimerTick) { _, _ in
                if demo.isEnabled { restTimer.start(seconds: 90) }
            }
            .onChange(of: demo.setToOpen, initial: true) { _, setID in
                if demo.isEnabled, let setID { path = [setID] }
            }
            .confirmationDialog("Finish this workout?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Finish workout") {
                    store.finishWorkout()
                    dismiss()
                }
            } message: {
                Text("Exercises with no sets are removed. Your lifts update the leaderboards straight away.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) {
                    store.discardWorkout()
                    dismiss()
                }
            } message: {
                Text("All sets and proof in this workout will be deleted.")
            }
        }
    }

    private func workoutList(_ session: WorkoutSession) -> some View {
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack {
                        Label(Format.duration(context.date.timeIntervalSince(session.startedAt)), systemImage: "clock")
                        Spacer()
                        Label(Format.volume(session.totalVolumeKg, store.unit), systemImage: "scalemass")
                        Spacer()
                        Label("\(session.workingSets.count) sets", systemImage: "list.number")
                    }
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                if let gym = store.gym(id: session.gymID) {
                    Label(gym.name, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                }
            }

            ForEach(session.entries) { entry in
                Section {
                    ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                        NavigationLink(value: set.id) {
                            SetRow(index: index, set: set, exerciseID: entry.exerciseID,
                                   isPR: ProgressAnalyzer.isPersonalRecord(set, exerciseID: entry.exerciseID,
                                                                           in: store.allSessions),
                                   unit: store.unit)
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { entry.sets[$0].id }.forEach { store.deleteSet(id: $0) }
                    }
                    Button {
                        logTarget = entry
                    } label: {
                        Label("Add set", systemImage: "plus.circle.fill")
                    }
                } header: {
                    HStack {
                        Text(entry.exercise?.name ?? entry.exerciseID)
                            .font(.headline)
                            .textCase(nil)
                            .foregroundStyle(.primary)
                        Spacer()
                        Menu {
                            Button("Remove exercise", systemImage: "trash", role: .destructive) {
                                store.removeEntry(id: entry.id)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }

            Section {
                Button {
                    showExercisePicker = true
                } label: {
                    Label("Add exercise", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}

struct SetRow: View {
    let index: Int
    let set: LiftSet
    let exerciseID: String
    let isPR: Bool
    let unit: WeightUnit

    var body: some View {
        let exercise = ExerciseLibrary.exercise(id: exerciseID)
        HStack(spacing: 12) {
            Text(set.isWarmup ? "W" : "\(index + 1)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(set.isWarmup ? Color.orange : Color.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(Format.liftSet(set, exercise: exercise, unit: unit))
                        .font(.body.weight(.semibold).monospacedDigit())
                    if isPR { PRBadge() }
                }
                HStack(spacing: 6) {
                    if StrengthCalculator.isRankable(reps: set.reps) && !set.isWarmup {
                        Text("e1RM \(Format.weight(StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise), unit))")
                    }
                    if let rpe = set.rpe {
                        Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if !set.isWarmup {
                VerificationBadge(status: set.verification, showsLabel: false)
            }
        }
    }
}

struct PRBanner: View {
    let celebration: PRCelebration
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill").font(.title2).foregroundStyle(Theme.gold)
            VStack(alignment: .leading) {
                Text("New personal record!").font(.headline)
                Text("\(celebration.exerciseName) · e1RM \(Format.weight(celebration.oneRepMaxKg, unit))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
