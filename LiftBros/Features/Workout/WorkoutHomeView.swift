import SwiftUI

struct WorkoutHomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showActiveWorkout = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    statsRow
                    workoutCard
                    toolsRow
                    history
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(greeting)
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(sessionID: id)
            }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                ActiveWorkoutView()
            }
        }
    }

    private var greeting: String {
        guard let name = store.profile?.displayName.split(separator: " ").first else { return "Train" }
        return "Hi, \(name)"
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(title: "Week streak", value: "\(ProgressAnalyzer.weeklyStreak(sessions: store.finishedSessions))",
                     systemImage: "flame.fill", tint: .orange)
            StatTile(title: "This week", value: "\(ProgressAnalyzer.workouts(in: store.finishedSessions))",
                     systemImage: "calendar", tint: .blue)
            StatTile(title: "Lifts logged", value: "\(store.personalBests.count)",
                     systemImage: "dumbbell.fill")
        }
    }

    @ViewBuilder private var workoutCard: some View {
        if let active = store.activeSession {
            Button {
                showActiveWorkout = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Workout in progress").font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.8))
                        Text(active.title).font(.title3.weight(.bold)).foregroundStyle(.white)
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            Text("\(Format.duration(context.date.timeIntervalSince(active.startedAt))) · \(active.workingSets.count) sets")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill").font(.title).foregroundStyle(.white)
                }
                .padding()
                .background(Theme.accent.gradient, in: RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                store.startWorkout()
                showActiveWorkout = true
            } label: {
                Label("Start workout", systemImage: "play.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var toolsRow: some View {
        HStack(spacing: 12) {
            NavigationLink {
                PlateCalculatorView()
            } label: {
                toolLabel("Plate calculator", systemImage: "circle.grid.2x1.fill")
            }
            NavigationLink {
                OneRepMaxCalculatorView()
            } label: {
                toolLabel("1RM calculator", systemImage: "function")
            }
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(_ title: String, systemImage: String) -> some View {
        HStack {
            Image(systemName: systemImage).foregroundStyle(Theme.accent)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(12)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder private var history: some View {
        Text("History").font(.title2.weight(.bold))
        if store.finishedSessions.isEmpty {
            ContentUnavailableView("No workouts yet",
                                   systemImage: "figure.strengthtraining.traditional",
                                   description: Text("Start a workout, log your sets and you'll be ranked against your gym and the rest of the UK."))
        } else {
            LazyVStack(spacing: 12) {
                ForEach(store.finishedSessions) { session in
                    NavigationLink(value: session.id) {
                        WorkoutSummaryCard(session: session, unit: store.unit)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WorkoutSummaryCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title).font(.headline)
                Spacer()
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                if let duration = session.duration {
                    Label(Format.duration(duration), systemImage: "clock")
                }
                Label(Format.volume(session.totalVolumeKg, unit), systemImage: "scalemass")
                Label("\(session.workingSets.count) sets", systemImage: "list.number")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            Text(session.entries.compactMap { $0.exercise?.name }.joined(separator: " · "))
                .font(.subheadline)
                .lineLimit(2)
            let verified = session.workingSets.filter { $0.verification == .verified }.count
            if verified > 0 {
                Label("\(verified) verified", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
