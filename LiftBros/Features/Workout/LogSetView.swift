import PhotosUI
import SwiftUI

struct LogSetView: View {
    let entryID: UUID
    let exerciseID: String
    /// Called after a set is saved, with whether it was a warm-up.
    var onLogged: (Bool) -> Void = { _ in }

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double = 0
    @State private var reps = 5
    @State private var useRPE = false
    @State private var rpe = 8.0
    @State private var isWarmup = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedProof: PickedProof?
    @State private var isLoadingProof = false
    @State private var errorMessage: String?
    @State private var didPrefill = false

    private var exercise: Exercise? { ExerciseLibrary.exercise(id: exerciseID) }
    private var unit: WeightUnit { store.unit }
    private var weightKg: Double { unit.toKg(weight) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WeightStepper(weight: $weight, step: unit == .kg ? (exercise?.incrementKg ?? 2.5) : 5,
                                  unit: unit, label: exercise?.isPerHand == true
                                    ? "\(unit.symbol) per dumbbell"
                                    : (exercise?.addsBodyweight == true ? "\(unit.symbol) added to bodyweight" : unit.symbol))
                        .padding(.vertical, 8)
                    Stepper(value: $reps, in: 1...50) {
                        HStack {
                            Text("Reps")
                            Spacer()
                            Text("\(reps)").font(.title3.weight(.bold).monospacedDigit())
                        }
                    }
                }

                Section {
                    Toggle("Warm-up set", isOn: $isWarmup)
                    Toggle("Record RPE", isOn: $useRPE.animation())
                    if useRPE {
                        Picker("RPE", selection: $rpe) {
                            ForEach([6.0, 6.5, 7.0, 7.5, 8.0, 8.5, 9.0, 9.5, 10.0], id: \.self) {
                                Text($0.formatted(.number.precision(.fractionLength(0...1)))).tag($0)
                            }
                        }
                    }
                } footer: {
                    if isWarmup { Text("Warm-up sets aren't ranked.") }
                }

                if !isWarmup, let exercise, let profile = store.profile {
                    preview(exercise: exercise, profile: profile)
                }

                if !isWarmup {
                    proofSection
                }
            }
            .navigationTitle(exercise?.name ?? "Log set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(isLoadingProof || (weight <= 0 && exercise?.addsBodyweight != true))
                }
            }
            .onAppear(perform: prefill)
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task { await loadProof(item) }
            }
            .alert("Proof error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func preview(exercise: Exercise, profile: UserProfile) -> some View {
        let load = StrengthCalculator.effectiveLoad(weightKg: weightKg, bodyweightKg: profile.bodyweightKg, exercise: exercise)
        let oneRM = StrengthCalculator.estimatedOneRepMax(load: load, reps: reps)
        let tier = StrengthCalculator.tier(oneRepMaxKg: oneRM, bodyweightKg: profile.bodyweightKg, exercise: exercise,
                                           sex: profile.sex)
        let best = store.personalBests[exercise.id]?.estimatedOneRepMaxKg ?? 0
        return Section("If you hit it") {
            if StrengthCalculator.isRankable(reps: reps) {
                LabeledContent("Estimated 1RM", value: Format.weight(oneRM, unit))
                LabeledContent("Pound for pound",
                               value: Format.ratio(StrengthCalculator.relativeStrength(oneRepMaxKg: oneRM,
                                                                                       bodyweightKg: profile.bodyweightKg)))
                LabeledContent("Tier") { TierBadge(tier: tier) }
                if best > 0 && oneRM > best {
                    Label("This would be a new PR", systemImage: "trophy.fill").foregroundStyle(Theme.gold)
                }
            } else {
                Text("Sets over \(StrengthCalculator.maxRankableReps) reps are logged but don't rank.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var proofSection: some View {
        Section {
            PhotosPicker(selection: $pickerItem, matching: .any(of: [.videos, .images])) {
                HStack {
                    Label(pickedProof == nil ? "Attach video proof" : "Replace proof",
                          systemImage: pickedProof == nil ? "video.badge.plus" : "arrow.triangle.2.circlepath")
                    Spacer()
                    if isLoadingProof { ProgressView() }
                }
            }
            if let pickedProof {
                Label(pickedProof.kind == .video ? "Video attached" : "Photo attached", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        } header: {
            Text("Proof (optional)")
        } footer: {
            Text("Sets with proof are reviewed and marked verified. Sets without proof still rank, marked unverified. You can also add proof later.")
        }
    }

    private func prefill() {
        guard !didPrefill else { return }
        didPrefill = true
        if let last = store.lastSet(inEntry: entryID) ?? store.lastSet(forExercise: exerciseID) {
            weight = (unit.fromKg(last.weightKg) * 10).rounded() / 10
            reps = last.reps
        } else if let exercise, let profile = store.profile, !exercise.addsBodyweight {
            // Suggest a sensible starting point: roughly a Silver-tier 8-rep weight.
            let suggested = StrengthCalculator.weightFor(
                reps: 8, oneRepMaxKg: exercise.standards.thresholds(for: profile.sex)[0] * profile.bodyweightKg)
            let step = exercise.incrementKg
            weight = (unit.fromKg((suggested / step).rounded() * step) * 10).rounded() / 10
            reps = 8
        }
    }

    private func loadProof(_ item: PhotosPickerItem) async {
        isLoadingProof = true
        defer { isLoadingProof = false }
        do {
            pickedProof = try await ProofImporter.load(item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let set = store.addSet(entryID: entryID, weightKg: max(0, weightKg), reps: reps,
                                     rpe: useRPE ? rpe : nil, isWarmup: isWarmup) else {
            dismiss()
            return
        }
        if let pickedProof, !isWarmup {
            do {
                try store.attachProof(pickedProof, toSet: set.id)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }
        onLogged(isWarmup)
        dismiss()
    }
}
