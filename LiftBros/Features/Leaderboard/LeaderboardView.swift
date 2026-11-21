import SwiftUI

enum RankingsRoute: Hashable {
    case lifter(UUID)
    case set(UUID)
}

struct LeaderboardView: View {
    @Binding var showPaywall: Bool

    @Environment(AppStore.self) private var store

    private enum ScopeChoice: String, CaseIterable {
        case gym, national
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
    @State private var rows: [LeaderboardRow] = []
    @State private var standing: NationalStanding?
    @State private var isLoading = true
    @State private var flagTarget: LeaderboardRow?
    @State private var showFlagThanks = false
    @State private var path: [RankingsRoute] = []
    private let demo = DemoDirector.shared

    private var query: LeaderboardQuery {
        LeaderboardQuery(exerciseID: exerciseID,
                         scope: scope == .gym ? .gym(store.profile?.gymID ?? "") : .unitedKingdom,
                         metric: metric, division: division, timeframe: timeframe)
    }

    private var exerciseName: String { ExerciseLibrary.exercise(id: exerciseID)?.name ?? "this lift" }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    controls
                    if store.isUsingSampleData { SampleDataBanner() }
                    yourPosition
                    board
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: RankingsRoute.self) { route in
                switch route {
                case .lifter(let id): LifterProfileView(lifterID: id, showPaywall: $showPaywall)
                case .set(let id): SetDetailView(setID: id)
                }
            }
            .task(id: ReloadKey(query: query, dataVersion: store.dataVersion)) {
                await reload()
            }
            .refreshable {
                store.clearCommunityCache()
                await reload()
            }
            .onChange(of: demo.leaderboardUK, initial: true) { _, uk in
                if demo.isEnabled { scope = uk ? .national : .gym }
            }
            .onChange(of: demo.leaderboardRelative, initial: true) { _, relative in
                if demo.isEnabled { metric = relative ? .relative : .absolute }
            }
            .onChange(of: demo.openTopLifterTick) { _, _ in
                if demo.isEnabled, let row = rows.first(where: { !$0.isCurrentUser }) {
                    path.append(.lifter(row.record.lifterID))
                }
            }
            .confirmationDialog("Report this lift?", isPresented: Binding(get: { flagTarget != nil },
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
                Text("\(row.record.displayName)'s \(Format.record(row.record, unit: store.unit)) will be sent to moderators.")
            }
            .alert("Thanks for reporting", isPresented: $showFlagThanks) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Moderators review reported lifts. Lifts reported several times are hidden until evidence is provided.")
            }
        }
    }

    // MARK: Header & controls

    private var header: some View {
        HStack(alignment: .top) {
            ScreenTitle(title: "Rankings", subtitle: scope == .gym ? (store.currentGym?.name ?? "My gym") : "United Kingdom")
            if scope == .gym, let partnership = store.currentPartnership, partnership.status.isLive {
                HStack(spacing: 4) {
                    Circle().fill(Theme.accent).frame(width: 7, height: 7)
                    Text("ON SCREEN").font(.caption2.weight(.black))
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.accent.opacity(0.14), in: Capsule())
                .padding(.top, 20)
                .accessibilityLabel("Your gym shows this leaderboard on its screens")
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            PillPicker(options: ScopeChoice.allCases, selection: $scope) { $0 == .gym ? "My Gym" : "National" }
            PillPicker(options: LeaderboardMetric.allCases, selection: $metric) { $0.displayName }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ExerciseLibrary.featuredIDs, id: \.self) { id in
                        Button {
                            exerciseID = id
                        } label: {
                            Chip(title: ExerciseLibrary.exercise(id: id)?.name ?? id, isSelected: exerciseID == id)
                        }
                        .buttonStyle(.plain)
                    }
                    Menu {
                        Picker("Exercise", selection: $exerciseID) {
                            ForEach(ExerciseLibrary.all) { Text($0.name).tag($0.id) }
                        }
                    } label: {
                        Chip(title: ExerciseLibrary.featuredIDs.contains(exerciseID) ? "More" : exerciseName,
                             isSelected: !ExerciseLibrary.featuredIDs.contains(exerciseID), systemImage: "ellipsis")
                    }
                    Menu {
                        Picker("Division", selection: $division) {
                            ForEach(Division.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Picker("Timeframe", selection: $timeframe) {
                            ForEach(LeaderboardTimeframe.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                    } label: {
                        Chip(title: "\(division.displayName) · \(timeframe.displayName)",
                             systemImage: "line.3.horizontal.decrease")
                    }
                }
            }
            HStack(spacing: 6) {
                Image(systemName: scope == .gym ? "hand.raised.fill" : "checkmark.seal.fill")
                Text(scope == .gym
                     ? "Honour system: every lift logged at your gym counts."
                     : "Top \(LeaderboardEngine.nationalListSize) in the UK. Video evidence required to be listed.")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(scope == .gym ? Theme.lavender : Theme.teal)
        }
    }

    // MARK: Your position

    @ViewBuilder private var yourPosition: some View {
        if let profile = store.profile {
            if !profile.privacy.showOnLeaderboards {
                Label("You're hidden from leaderboards. Turn this on in Profile → Privacy.", systemImage: "eye.slash")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else if scope == .national {
                if let standing {
                    NationalStandingCard(standing: standing, metric: metric, unit: store.unit,
                                         exerciseName: exerciseName, evidenceLeft: store.evidenceUploadsLeft,
                                         isPro: store.isPro,
                                         onUploadEvidence: { path.append(.set(standing.bestRecord?.id ?? UUID())) },
                                         onUpgrade: { showPaywall = true })
                }
            } else if let mine = rows.first(where: \.isCurrentUser) {
                YourRankCard(row: mine, rows: rows, metric: metric, profile: profile, unit: store.unit)
            } else if !isLoading {
                Label("Log a set of \(exerciseName) and you'll be ranked at your gym straight away.",
                      systemImage: "arrow.up.forward.circle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            }
        }
    }

    // MARK: Board

    @ViewBuilder private var board: some View {
        if isLoading && rows.isEmpty {
            ProgressView().frame(maxWidth: .infinity).padding(40)
        } else if rows.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "trophy").font(.largeTitle).foregroundStyle(Theme.accent)
                Text(scope == .gym ? "No lifts at your gym yet. Be the first!" : "No verified lifts yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .card()
        } else {
            if rows.count >= 3 {
                Podium(rows: Array(rows.prefix(3)), metric: metric, unit: store.unit) { row in
                    open(row)
                }
            }
            SectionHeader(title: scope == .gym
                          ? "\(rows.count) lifters"
                          : "Top \(rows.count) · UK")
            LazyVStack(spacing: 8) {
                ForEach(rows.count >= 3 ? Array(rows.dropFirst(3)) : rows) { row in
                    Button {
                        open(row)
                    } label: {
                        LeaderboardRowView(row: row, metric: metric, unit: store.unit,
                                           gymName: scope == .national ? store.gym(id: row.record.gymID)?.name : nil)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !row.isCurrentUser {
                            Button("Report lift", systemImage: "flag") { flagTarget = row }
                        }
                    }
                }
            }
        }
    }

    private func open(_ row: LeaderboardRow) {
        if !row.isCurrentUser { path.append(.lifter(row.record.lifterID)) }
    }

    private func reload() async {
        isLoading = true
        let currentQuery = query
        rows = await store.leaderboard(for: currentQuery)
        if scope == .national {
            standing = await store.nationalStanding(for: currentQuery)
        } else {
            standing = nil
        }
        isLoading = false
    }
}

// MARK: - Components

struct Podium: View {
    let rows: [LeaderboardRow]
    let metric: LeaderboardMetric
    let unit: WeightUnit
    let onTap: (LeaderboardRow) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if rows.count == 3 {
                column(rows[1], height: 96, color: Theme.silver)
                column(rows[0], height: 130, color: Theme.accent)
                column(rows[2], height: 76, color: Theme.bronze)
            }
        }
        .padding(.top, 8)
    }

    private func column(_ row: LeaderboardRow, height: CGFloat, color: Color) -> some View {
        Button {
            onTap(row)
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(name: row.record.displayName, size: row.rank == 1 ? 62 : 50)
                        .overlay(Circle().stroke(color, lineWidth: 3))
                    if row.record.verification == .verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.teal)
                            .background(Circle().fill(Theme.background).padding(-2))
                    }
                }
                Text(row.isCurrentUser ? "You" : (row.record.displayName.split(separator: " ").first.map(String.init) ?? ""))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(Format.score(row.score, metric: metric, unit: unit))
                    .font(.stat(14))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                ZStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [color, color.opacity(0.35)], startPoint: .top, endPoint: .bottom))
                    Text("\(row.rank)")
                        .font(.display(34))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.top, 8)
                }
                .frame(height: height)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
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
            AvatarView(name: row.record.displayName, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(row.isCurrentUser ? "\(row.record.displayName) (you)" : row.record.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if row.record.isPro { ProBadge() }
                    VerificationBadge(status: row.record.verification, showsLabel: false)
                }
                Text([Format.record(row.record, unit: unit), gymName].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Format.score(row.score, metric: metric, unit: unit))
                    .font(.stat(16).monospacedDigit())
                    .foregroundStyle(.white)
                TierBadge(tier: row.tier, compact: true)
            }
        }
        .padding(12)
        .background(row.isCurrentUser ? Theme.accent.opacity(0.14) : Theme.surface,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(row.isCurrentUser ? Theme.accent.opacity(0.6) : Color.clear))
        .accessibilityElement(children: .combine)
    }
}

/// Gym (honour-system) position card.
struct YourRankCard: View {
    let row: LeaderboardRow
    let rows: [LeaderboardRow]
    let metric: LeaderboardMetric
    let profile: UserProfile
    let unit: WeightUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("#\(row.rank)")
                    .font(.display(60))
                    .foregroundStyle(Theme.onAccent)
                Text("OF \(rows.count) AT YOUR GYM")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.onAccent.opacity(0.7))
                Spacer()
                TierBadge(tier: row.tier)
                    .colorScheme(.light)
            }
            HStack {
                Text(Format.record(row.record, unit: unit))
                Text("·")
                Text(Format.score(row.score, metric: metric, unit: unit)).fontWeight(.heavy)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.onAccent)
            if let hint = nextTargetHint {
                Label(hint, systemImage: "target")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.onAccent.opacity(0.8))
            }
        }
        .card(Theme.accent, padding: 18)
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
            return row.rank == 1 ? "Top of your gym. Now take it national." : nil
        }
        return "Top of your gym! An e1RM of \(Format.weight(target, unit)) gets you \(next.displayName)."
    }
}

/// National position card: shows your place and asks for evidence when needed.
struct NationalStandingCard: View {
    let standing: NationalStanding
    let metric: LeaderboardMetric
    let unit: WeightUnit
    let exerciseName: String
    let evidenceLeft: Int?
    let isPro: Bool
    let onUploadEvidence: () -> Void
    let onUpgrade: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch standing.status {
            case .noLift:
                Text("Log a set of \(exerciseName) to see where you'd rank in the UK.")
                    .font(.subheadline)
            case .listed:
                rankLine(rank: standing.listedRank ?? standing.provisionalRank ?? 0, caption: "IN THE UK")
                bestLine
                Label("Verified and on the national leaderboard.", systemImage: "checkmark.seal.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            case .needsEvidence:
                rankLine(rank: standing.provisionalRank ?? 0, caption: "IN THE UK · PROVISIONAL")
                bestLine
                Text("You've made the national top \(LeaderboardEngine.nationalListSize)! Upload video evidence of this lift to appear on the national leaderboard.")
                    .font(.subheadline)
                if let listed = standing.listedRank {
                    Text("Meanwhile your verified lift is listed at #\(listed).")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
                if isPro || (evidenceLeft ?? 0) > 0 {
                    Button("Upload evidence", action: onUploadEvidence)
                        .buttonStyle(PrimaryButtonStyle())
                    if let evidenceLeft {
                        Text("\(evidenceLeft) of \(PlanLimits.freeEvidenceUploadsPerMonth) free uploads left this month")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                } else {
                    Button("Go Pro for unlimited evidence", action: onUpgrade)
                        .buttonStyle(PrimaryButtonStyle())
                }
            case .pendingReview:
                rankLine(rank: standing.provisionalRank ?? 0, caption: "IN THE UK · IN REVIEW")
                bestLine
                Label(isPro ? "Priority review: you'll appear once your evidence is approved."
                            : "Your evidence is being reviewed. You'll appear once it's approved.",
                      systemImage: "clock.badge.checkmark")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.orange)
            case .outsideTopList:
                rankLine(rank: standing.provisionalRank ?? 0, caption: "OF \(standing.totalRanked) IN THE UK")
                bestLine
                Text("The national board shows the top \(LeaderboardEngine.nationalListSize). Keep climbing! Once you break in, you'll be asked for evidence.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 18)
        .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
            .stroke(standing.status == .needsEvidence ? Theme.accent : Theme.stroke, lineWidth: 1.5))
    }

    private func rankLine(rank: Int, caption: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("#\(rank)").font(.display(56)).foregroundStyle(Theme.accent)
            Text(caption).font(.caption.weight(.heavy)).foregroundStyle(Theme.secondaryText)
        }
    }

    @ViewBuilder private var bestLine: some View {
        if let record = standing.bestRecord, let score = standing.bestScore {
            HStack {
                Text(Format.record(record, unit: unit))
                Text("·")
                Text(Format.score(score, metric: metric, unit: unit)).fontWeight(.heavy)
                Spacer()
                VerificationBadge(status: record.verification)
            }
            .font(.subheadline)
        }
    }
}
