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
            .navigationTitle((store.activeSession?.title ?? "Workout").uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
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
                        Text("Finish")
                            .font(.subheadline.weight(.heavy))
                            .foregroundStyle(Theme.onAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Theme.accent, in: Capsule())
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
                    restTimer.start(seconds: isWarmup ? 60 : store.restSeconds)
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
                Text("All sets and evidence in this workout will be deleted.")
            }
        }
    }

    private func workoutList(_ session: WorkoutSession) -> some View {
        List {
            Section {
                VStack(spacing: 14) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        VStack(spacing: 2) {
                            Text("ELAPSED")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.secondaryText)
                            Text(Format.clock(context.date.timeIntervalSince(session.startedAt)))
                                .font(.system(size: 64, weight: .black).width(.condensed).monospacedDigit())
                                .foregroundStyle(.white)
                        }
                    }
                    HStack(spacing: 8) {
                        workoutStat("VOLUME", Format.volume(session.totalVolumeKg, store.unit))
                        workoutStat("SETS", "\(session.workingSets.count)")
                        workoutStat("LIFTS", "\(session.entries.count)")
                    }
                    if let gym = store.gym(id: session.gymID) {
                        GymCaption(name: gym.name)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
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
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                    }
                } header: {
                    HStack {
                        Text((entry.exercise?.name ?? entry.exerciseID).uppercased())
                            .font(.display(19))
                            .foregroundStyle(.white)
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
                }
                .buttonStyle(PrimaryButtonStyle())
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .darkList()
    }

    private func workoutStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.stat(17)).foregroundStyle(.white)
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .foregroundStyle(set.isWarmup ? Theme.orange : Theme.secondaryText)
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
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 44, height: 44)
                .background(Theme.onAccent, in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text("NEW PERSONAL RECORD").font(.display(19))
                Text("\(celebration.exerciseName) · e1RM \(Format.weight(celebration.oneRepMaxKg, unit))")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Theme.onAccent)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.accent.opacity(0.35), radius: 18)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
