import SwiftUI

struct WorkoutHomeView: View {
    @Binding var showPaywall: Bool

    @Environment(AppStore.self) private var store
    @State private var showActiveWorkout = false
    private let demo = DemoDirector.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    todayTiles
                    workoutCard
                    weekCard
                    tools
                    history
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 100)   // clear the floating tab bar
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                WorkoutDetailView(sessionID: id)
            }
            .fullScreenCover(isPresented: $showActiveWorkout) {
                ActiveWorkoutView()
            }
            .onChange(of: demo.showActiveWorkout) { _, show in
                if demo.isEnabled { showActiveWorkout = show }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 12) {
            AvatarView(name: store.profile?.displayName ?? "", size: 48)
            VStack(alignment: .leading, spacing: 1) {
                Text("WELCOME BACK,")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 6) {
                    Text((store.profile?.displayName ?? "Lifter").uppercased())
                        .font(.display(24))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if store.isPro { ProBadge() }
                }
            }
            Spacer()
            if !store.isPro {
                CircleIconButton(systemImage: "crown.fill", tint: Theme.accent) { showPaywall = true }
                    .accessibilityLabel("LiftBros Pro")
            }
        }
    }

    private var todayTiles: some View {
        let finished = store.finishedSessions
        let streak = ProgressAnalyzer.weeklyStreak(sessions: finished)
        let thisWeek = ProgressAnalyzer.workouts(in: finished)
        let goal = max(1, store.profile?.trainingDaysPerWeek ?? 3)
        let bests = store.personalBests.values
        let verified = bests.filter { $0.set.verification == .verified }.count
        return HStack(spacing: 10) {
            RingStatTile(symbol: "flame.fill", value: "\(streak) wk", label: "Streak",
                         progress: Double(streak) / 12, tint: Theme.orange)
            RingStatTile(symbol: "calendar", value: "\(thisWeek)/\(goal)", label: "This week",
                         progress: Double(thisWeek) / Double(goal), tint: Theme.accent)
            RingStatTile(symbol: "checkmark.seal.fill", value: "\(verified)", label: "Verified PBs",
                         progress: bests.isEmpty ? 0 : Double(verified) / Double(bests.count), tint: Theme.teal)
        }
    }

    @ViewBuilder private var workoutCard: some View {
        if let active = store.activeSession {
            Button {
                showActiveWorkout = true
            } label: {
                HeroCard(colors: [Theme.teal, Color(red: 0.08, green: 0.45, blue: 0.42)],
                         eyebrow: "In progress", title: active.title, symbol: "figure.strengthtraining.traditional") {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        HStack(spacing: 8) {
                            HeroPill(systemImage: "clock", text: Format.duration(context.date.timeIntervalSince(active.startedAt)))
                            HeroPill(systemImage: "list.number", text: "\(active.workingSets.count) sets")
                            HeroPill(systemImage: "scalemass", text: Format.volume(active.totalVolumeKg, store.unit))
                        }
                    }
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                store.startWorkout()
                showActiveWorkout = true
            } label: {
                HeroCard(colors: [Theme.accent, Color(red: 0.62, green: 0.86, blue: 0.10)], foreground: Theme.onAccent,
                         eyebrow: store.currentGym?.name ?? "Today", title: "Start workout",
                         symbol: "figure.strengthtraining.functional") {
                    HeroPill(systemImage: "play.fill", text: "Tap to begin", dark: true)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var weekCard: some View {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        var volumes = Array(repeating: 0.0, count: 7)
        for session in store.allSessions where session.startedAt >= weekStart {
            let day = min(6, max(0, calendar.dateComponents([.day], from: weekStart, to: session.startedAt).day ?? 0))
            volumes[day] += session.totalVolumeKg
        }
        let today = min(6, max(0, calendar.dateComponents([.day], from: weekStart, to: now).day ?? 0))
        let bars = (0..<7).map { HighlightBarChart.Bar(id: $0, label: labels[$0], value: volumes[$0], isHighlighted: $0 == today) }
        return VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("THIS WEEK").font(.display(20))
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text("VOLUME").font(.caption2.weight(.bold)).foregroundStyle(Theme.secondaryText)
                    Text(Format.volume(volumes.reduce(0, +), store.unit)).font(.stat(18))
                }
            }
            HighlightBarChart(bars: bars, height: 110)
        }
        .card()
    }

    private var tools: some View {
        HStack(spacing: 10) {
            NavigationLink {
                PlateCalculatorView()
            } label: {
                toolLabel("Plates", systemImage: "circle.grid.2x1.fill", tint: Theme.lavender)
            }
            NavigationLink {
                OneRepMaxCalculatorView()
            } label: {
                toolLabel("1RM calc", systemImage: "function", tint: Theme.pink)
            }
        }
        .buttonStyle(.plain)
    }

    private func toolLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(Theme.onAccent)
                .frame(width: 34, height: 34)
                .background(tint, in: Circle())
            Text(title).font(.subheadline.weight(.bold)).foregroundStyle(.white)
            Spacer()
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.secondaryText)
        }
        .card(padding: 12, radius: 20)
    }

    @ViewBuilder private var history: some View {
        SectionHeader(title: "History")
        if store.finishedSessions.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 40))
                    .foregroundStyle(Theme.accent)
                Text("No workouts yet").font(.headline)
                Text("Start a workout and every set you log counts on your gym's leaderboard.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .card()
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

/// Big gradient card with condensed headline and a large symbol, after the reference "workout plan" cards.
struct HeroCard<Footer: View>: View {
    let colors: [Color]
    var foreground: Color = .white
    let eyebrow: String
    let title: String
    let symbol: String
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 150, weight: .bold))
                .foregroundStyle(foreground.opacity(0.16))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 18, y: 22)
            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(foreground.opacity(0.85))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(foreground.opacity(0.14), in: Capsule())
                Text(title.uppercased())
                    .font(.display(36))
                    .foregroundStyle(foreground)
                    .lineLimit(2)
                Spacer(minLength: 0)
                footer()
            }
            .padding(18)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct HeroPill: View {
    let systemImage: String
    let text: String
    var dark = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(dark ? Theme.onAccent : .white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((dark ? Color.black : Color.white).opacity(0.16), in: Capsule())
    }
}

struct WorkoutSummaryCard: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(session.title.uppercased()).font(.display(20))
                Spacer()
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryText)
            }
            HStack(spacing: 8) {
                if let duration = session.duration {
                    statPill("clock", Format.duration(duration))
                }
                statPill("scalemass", Format.volume(session.totalVolumeKg, unit))
                statPill("list.number", "\(session.workingSets.count) sets")
            }
            Text(session.entries.compactMap { $0.exercise?.name }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(2)
            let verified = session.workingSets.filter { $0.verification == .verified }.count
            if verified > 0 {
                Label("\(verified) verified", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func statPill(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Theme.surfaceRaised, in: Capsule())
    }
}
