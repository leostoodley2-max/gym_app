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
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let context = store.findSet(id: setID), let profile = store.profile {
                content(context, profile: profile)
            } else {
                ContentUnavailableView("Set not found", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle("SET DETAILS")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) { PaywallView() }
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
                    Text((exercise?.name ?? context.exerciseID).uppercased())
                        .font(.display(22))
                        .foregroundStyle(Theme.secondaryText)
                    Text(Format.liftSet(set, exercise: exercise, unit: store.unit))
                        .font(.display(44).monospacedDigit())
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
                    if set.proof != nil || store.canUploadEvidence {
                        PhotosPicker(selection: $pickerItem, matching: .any(of: [.videos, .images])) {
                            HStack {
                                Label(set.proof == nil ? "Upload video evidence" : "Replace evidence",
                                      systemImage: set.proof == nil ? "video.badge.plus" : "arrow.triangle.2.circlepath")
                                    .foregroundStyle(Theme.accent)
                                Spacer()
                                if isUploading { ProgressView() }
                            }
                        }
                        .disabled(isUploading)
                    } else {
                        Button {
                            showPaywall = true
                        } label: {
                            Label("Monthly evidence limit reached. Go Pro for unlimited.", systemImage: "crown.fill")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    if let left = store.evidenceUploadsLeft, set.proof == nil {
                        Text("\(left) of \(PlanLimits.freeEvidenceUploadsPerMonth) free uploads left this month")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    if set.proof != nil {
                        Button("Remove evidence", role: .destructive) { store.removeProof(fromSet: setID) }
                    }
                } header: {
                    Text("National leaderboard evidence")
                } footer: {
                    Text("Good evidence is one continuous video showing the plates or pin, your whole body and every rep. Videos are only seen by reviewers.")
                }
            }

            Section {
                Button("Delete set", role: .destructive) { confirmDelete = true }
            }
        }
        .darkList()
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
