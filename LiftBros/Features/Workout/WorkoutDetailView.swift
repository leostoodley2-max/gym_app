import SwiftUI

struct WorkoutDetailView: View {
    let sessionID: UUID

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        Group {
            if let session = store.session(id: sessionID) {
                List {
                    Section {
                        LabeledContent("Date", value: session.startedAt.formatted(date: .complete, time: .shortened))
                        if let duration = session.duration {
                            LabeledContent("Duration", value: Format.duration(duration))
                        }
                        LabeledContent("Volume", value: Format.volume(session.totalVolumeKg, store.unit))
                        if let gym = store.gym(id: session.gymID) {
                            LabeledContent("Gym", value: gym.name)
                        }
                    }
                    ForEach(session.entries) { entry in
                        Section(entry.exercise?.name ?? entry.exerciseID) {
                            ForEach(Array(entry.sets.enumerated()), id: \.element.id) { index, set in
                                NavigationLink {
                                    SetDetailView(setID: set.id)
                                } label: {
                                    SetRow(index: index, set: set, exerciseID: entry.exerciseID,
                                           isPR: ProgressAnalyzer.isPersonalRecord(set, exerciseID: entry.exerciseID,
                                                                                   in: store.allSessions),
                                           unit: store.unit)
                                }
                            }
                        }
                    }
                }
                .darkList()
                .navigationTitle(session.title.uppercased())
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Delete workout", systemImage: "trash", role: .destructive) { confirmDelete = true }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            } else {
                ContentUnavailableView("Workout not found", systemImage: "questionmark.circle")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this workout?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete workout", role: .destructive) {
                store.deleteSession(id: sessionID)
                dismiss()
            }
        } message: {
            Text("Its lifts will be removed from leaderboards.")
        }
    }
}
