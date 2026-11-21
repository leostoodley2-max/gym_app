import SwiftUI

struct ExercisePickerView: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var matches: [Exercise] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return ExerciseLibrary.all }
        return ExerciseLibrary.all.filter {
            $0.name.lowercased().contains(query) || $0.equipment.displayName.lowercased().contains(query)
                || $0.category.displayName.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if search.isEmpty {
                    Section("Popular") {
                        ForEach(ExerciseLibrary.featuredIDs.compactMap(ExerciseLibrary.exercise(id:))) { row($0) }
                    }
                }
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
                    let items = matches.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.displayName) {
                            ForEach(items) { row($0) }
                        }
                    }
                }
            }
            .darkList()
            .searchable(text: $search, prompt: "Search exercises")
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        Button {
            onSelect(exercise.id)
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(exercise.name).foregroundStyle(.primary)
                    Text(exercise.equipment.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle").foregroundStyle(Theme.accent)
            }
        }
    }
}

/// Compact menu for choosing an exercise from a list of IDs.
struct ExerciseMenu: View {
    @Binding var selection: String
    var exerciseIDs: [String] = ExerciseLibrary.all.map(\.id)

    var body: some View {
        Menu {
            Picker("Exercise", selection: $selection) {
                ForEach(exerciseIDs, id: \.self) { id in
                    Text(ExerciseLibrary.exercise(id: id)?.name ?? id).tag(id)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(ExerciseLibrary.exercise(id: selection)?.name ?? "Exercise")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
                Image(systemName: "chevron.up.chevron.down").font(.caption)
            }
        }
    }
}
