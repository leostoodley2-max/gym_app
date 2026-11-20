import SwiftUI

struct LeaderboardView: View {
    @Environment(AppStore.self) private var store

    private enum ScopeChoice: String, CaseIterable {
        case gym, uk
    }

    private struct ReloadKey: Hashable {
        let query: LeaderboardQuery
        let dataVersion: Int
    }

    @State private var scope: ScopeChoice = .gym
    @State private var exerciseID = "bench-press"
    @State private var metric: LeaderboardMetric = .absolute
    @State private var division: Division = .open
    @State private var timeframe: LeaderboardTimeframe = .allTime
    @State private var verifiedOnly = false
    @State private var rows: [LeaderboardRow] = []
    @State private var isLoading = true
    @State private var flagTarget: LeaderboardRow?
    @State private var showFlagThanks = false
    @State private var path: [UUID] = []
    private let demo = DemoDirector.shared

    private var query: LeaderboardQuery {
        LeaderboardQuery(exerciseID: exerciseID,
                         scope: scope == .gym ? .gym(store.profile?.gymID ?? "") : .unitedKingdom,
                         metric: metric, division: division, timeframe: timeframe, verifiedOnly: verifiedOnly)
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                controls
                yourRank
                Section {
                    if isLoading && rows.isEmpty {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if rows.isEmpty {
                        ContentUnavailableView("No lifts yet", systemImage: "trophy",
                                               description: Text("Nobody has logged this lift with these filters. Be the first!"))
                    }
                    ForEach(rows) { row in
                        rowView(row)
                    }
                } header: {
                    Text("\(rows.count) lifters · \(scopeTitle)")
                }
            }
            .navigationTitle("Rankings")
            .navigationDestination(for: UUID.self) { lifterID in
                LifterProfileView(lifterID: lifterID)
            }
            .task(id: ReloadKey(query: query, dataVersion: store.dataVersion)) {
                await reload()
            }
            .onChange(of: demo.leaderboardUK, initial: true) { _, uk in
                if demo.isEnabled { scope = uk ? .uk : .gym }
            }
            .onChange(of: demo.leaderboardRelative, initial: true) { _, relative in
                if demo.isEnabled { metric = relative ? .relative : .absolute }
            }
            .onChange(of: demo.openTopLifterTick) { _, _ in
                if demo.isEnabled, let row = rows.first(where: { !$0.isCurrentUser }) {
                    path.append(row.record.lifterID)
                }
            }
            .refreshable {
                store.clearCommunityCache()
                await reload()
            }
            .confirmationDialog("Flag this lift?", isPresented: Binding(get: { flagTarget != nil },
                                                                        set: { if !$0 { flagTarget = nil } }),
                                titleVisibility: .visible, presenting: flagTarget) { row in
                ForEach(FlagReason.allCases, id: \.self) { reason in
                    Button(reason.displayName) {
                        Task {
                            await store.flag(row.record, reason: reason)
                            showFlagThanks = true
                        }
                    }
                }
            } message: { row in
                Text("\(row.record.displayName)'s \(Format.record(row.record, unit: store.unit)) will be sent to moderators for review.")
            }
            .alert("Thanks for flagging", isPresented: $showFlagThanks) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Moderators review flagged lifts. Unverified lifts with repeated flags are hidden until proof is provided.")
            }
        }
    }

    private var scopeTitle: String {
        scope == .gym ? (store.currentGym?.name ?? "My gym") : "United Kingdom"
    }

    private var controls: some View {
        Section {
            Picker("Scope", selection: $scope) {
                Text("My Gym").tag(ScopeChoice.gym)
                Text("United Kingdom").tag(ScopeChoice.uk)
            }
            .pickerStyle(.segmented)

            Picker("Ranking", selection: $metric) {
                ForEach(LeaderboardMetric.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack {
                ExerciseMenu(selection: $exerciseID)
                Spacer()
                Menu {
                    Picker("Division", selection: $division) {
                        ForEach(Division.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Timeframe", selection: $timeframe) {
                        ForEach(LeaderboardTimeframe.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                } label: {
                    Label("\(division.displayName) · \(timeframe.displayName)", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.subheadline)
                }
            }

            Toggle(isOn: $verifiedOnly) {
                Label("Verified lifts only", systemImage: "checkmark.seal.fill")
            }
            .tint(.green)
        } footer: {
            Text(metric == .absolute
                 ? "Ranked by estimated one-rep max from each lifter's best set (1–12 reps)."
                 : "Pound for pound: estimated one-rep max divided by bodyweight at the time of the lift.")
        }
    }

    @ViewBuilder private var yourRank: some View {
        if let profile = store.profile {
            Section("Your position") {
                if !profile.privacy.showOnLeaderboards {
                    Label("You're hidden from leaderboards. Turn this on in Profile → Privacy.", systemImage: "eye.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if let mine = rows.first(where: \.isCurrentUser) {
                    YourRankCard(row: mine, rows: rows, metric: metric, profile: profile, unit: store.unit)
                } else {
                    Label(verifiedOnly
                          ? "You don't have a verified \(ExerciseLibrary.exercise(id: exerciseID)?.name ?? "lift") yet. Add proof to a set to rank here."
                          : "Log a set of \(ExerciseLibrary.exercise(id: exerciseID)?.name ?? "this lift") to get ranked.",
                          systemImage: "arrow.up.forward.circle")
                        .font(.subheadline)
                }
            }
        }
    }

    @ViewBuilder private func rowView(_ row: LeaderboardRow) -> some View {
        let label = LeaderboardRowView(row: row, metric: metric, unit: store.unit,
                                       gymName: scope == .uk ? store.gym(id: row.record.gymID)?.name : nil)
        if row.isCurrentUser {
            label.listRowBackground(Theme.accent.opacity(0.12))
        } else {
            NavigationLink(value: row.record.lifterID) { label }
                .swipeActions {
                    Button {
                        flagTarget = row
                    } label: {
                        Label("Flag", systemImage: "flag.fill")
                    }
                    .tint(.orange)
                }
        }
    }

    private func reload() async {
        isLoading = true
        rows = await store.leaderboard(for: query)
        isLoading = false
    }
}

struct LeaderboardRowView: View {
    let row: LeaderboardRow
    let metric: LeaderboardMetric
    let unit: WeightUnit
    let gymName: String?

    var body: some View {
        HStack(spacing: 10) {
            RankMedal(rank: row.rank)
            AvatarView(name: row.record.displayName, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(row.isCurrentUser ? "\(row.record.displayName) (you)" : row.record.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    VerificationBadge(status: row.record.verification, showsLabel: false)
                }
                Text([Format.record(row.record, unit: unit), gymName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Format.score(row.score, metric: metric, unit: unit))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                TierBadge(tier: row.tier, compact: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct YourRankCard: View {
    let row: LeaderboardRow
    let rows: [LeaderboardRow]
    let metric: LeaderboardMetric
    let profile: UserProfile
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(row.rank)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("of \(rows.count)").foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Top \(max(1, Int((100 - LeaderboardEngine.percentile(rank: row.rank, of: rows.count)).rounded(.up))))%")
                        .font(.headline)
                    TierBadge(tier: row.tier)
                }
            }
            HStack {
                Text(Format.record(row.record, unit: unit))
                Text("·")
                Text(Format.score(row.score, metric: metric, unit: unit)).fontWeight(.semibold)
                Spacer()
                VerificationBadge(status: row.record.verification)
            }
            .font(.subheadline)
            if let hint = nextTargetHint {
                Label(hint, systemImage: "target")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var nextTargetHint: String? {
        if row.rank > 1, let ahead = rows.last(where: { $0.rank < row.rank }) {
            let gap = ahead.score - row.score
            let gapText = metric == .absolute ? Format.weight(gap, unit) : "\(gap.formatted(.number.precision(.fractionLength(2))))× BW"
            return "\(gapText) more on your e1RM to pass \(ahead.record.displayName.split(separator: " ").first.map(String.init) ?? "the next lifter")."
        }
        guard let exercise = ExerciseLibrary.exercise(id: row.record.exerciseID),
              let target = StrengthCalculator.oneRepMaxForNextTier(currentTier: row.tier, bodyweightKg: profile.bodyweightKg,
                                                                   exercise: exercise, sex: profile.sex),
              let next = row.tier.next else {
            return row.rank == 1 ? "You're top of the board. Get it verified to make it official!" : nil
        }
        return "Top of the board! An e1RM of \(Format.weight(target, unit)) gets you \(next.displayName)."
    }
}
