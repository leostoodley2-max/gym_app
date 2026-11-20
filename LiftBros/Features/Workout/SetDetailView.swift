import PhotosUI
import SwiftUI

struct SetDetailView: View {
    let setID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let context = store.findSet(id: setID), let profile = store.profile {
                content(context, profile: profile)
            } else {
                ContentUnavailableView("Set not found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("Set details")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .alert("Upload failed", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func content(_ context: SetContext, profile: UserProfile) -> some View {
        let exercise = ExerciseLibrary.exercise(id: context.exerciseID)
        let set = context.set
        let oneRM = StrengthCalculator.estimatedOneRepMax(for: set, exercise: exercise)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise?.name ?? context.exerciseID).font(.title2.weight(.bold))
                    Text(Format.liftSet(set, exercise: exercise, unit: store.unit))
                        .font(.title.weight(.heavy).monospacedDigit())
                    Text(set.performedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if !set.isWarmup && StrengthCalculator.isRankable(reps: set.reps), let exercise {
                    LabeledContent("Estimated 1RM", value: Format.weight(oneRM, store.unit))
                    LabeledContent("Pound for pound",
                                   value: Format.ratio(StrengthCalculator.relativeStrength(oneRepMaxKg: oneRM,
                                                                                           bodyweightKg: set.bodyweightKg)))
                    LabeledContent("Bodyweight at the time", value: Format.weight(set.bodyweightKg, store.unit))
                    LabeledContent("Tier") {
                        TierBadge(tier: StrengthCalculator.tier(oneRepMaxKg: oneRM, bodyweightKg: set.bodyweightKg,
                                                                exercise: exercise, sex: profile.sex))
                    }
                }
                if let rpe = set.rpe {
                    LabeledContent("RPE", value: rpe.formatted(.number.precision(.fractionLength(0...1))))
                }
            }

            if !set.isWarmup {
                Section {
                    HStack {
                        VerificationBadge(status: set.verification)
                        Spacer()
                        if set.verification == .pending { ProgressView() }
                    }
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    VerificationExplainer(status: set.verification)
                    if let proof = set.proof {
                        ProofPreview(media: proof, url: store.proofURL(for: proof))
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    }
                    PhotosPicker(selection: $pickerItem, matching: .any(of: [.videos, .images])) {
                        HStack {
                            Label(set.proof == nil ? "Upload video proof" : "Replace proof",
                                  systemImage: set.proof == nil ? "video.badge.plus" : "arrow.triangle.2.circlepath")
                            Spacer()
                            if isUploading { ProgressView() }
                        }
                    }
                    .disabled(isUploading)
                    if set.proof != nil {
                        Button("Remove proof", role: .destructive) { store.removeProof(fromSet: setID) }
                    }
                } header: {
                    Text("Verification")
                } footer: {
                    Text("Good proof shows the plates or pin, your whole body and every rep. Videos stay private to reviewers unless you make your progress public.")
                }
            }

            Section {
                Button("Delete set", role: .destructive) { confirmDelete = true }
            }
        }
        .confirmationDialog("Delete this set?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete set", role: .destructive) {
                store.deleteSet(id: setID)
                dismiss()
            }
        }
    }

    private func upload(_ item: PhotosPickerItem) async {
        isUploading = true
        defer {
            isUploading = false
            pickerItem = nil
        }
        do {
            let picked = try await ProofImporter.load(item)
            try store.attachProof(picked, toSet: setID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
