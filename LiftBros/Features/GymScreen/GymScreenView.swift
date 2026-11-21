import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Pairing flow for a gym's leaderboard screen (iPad / Apple TV via AirPlay / spare phone).
struct GymScreenFlow: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var partnership: GymPartnership?
    @State private var isPairing = false
    @State private var error: String?
    private let demo = DemoDirector.shared

    var body: some View {
        Group {
            if let partnership, let gym = store.gym(id: partnership.gymID) {
                GymDisplayView(partnership: partnership, gym: gym) { dismiss() }
            } else {
                pairing
            }
        }
        .task {
            // Demo mode pairs the sample screen for the user's gym automatically.
            if demo.isEnabled {
                if let current = store.currentPartnership {
                    partnership = current
                } else {
                    partnership = await store.pairScreen(code: "WORC-2026")
                }
            }
        }
    }

    private var pairing: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()
                CircleIconButton(systemImage: "xmark") { dismiss() }
            }
            Image(systemName: "tv").font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("GYM SCREEN MODE").font(.display(40))
            Text("Turn this device into your gym's live leaderboard screen. Enter the pairing code from your LiftBros partner dashboard.")
                .foregroundStyle(Theme.secondaryText)
            TextField("e.g. WORC-2026", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.stat(28).monospaced())
                .padding()
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            Button {
                Task { await pair() }
            } label: {
                if isPairing { ProgressView().tint(Theme.onAccent) } else { Text("Pair screen") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(code.count < 4 || isPairing)
            if store.isUsingSampleData {
                Text("Preview codes: WORC-2026 (PureGym Worcester), ABBY-7788 (Abbey Stadium), WYRE-0001 (Wyreside Barbell).")
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            Text("Not a partner yet? See Profile → LiftBros for gyms.")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(24)
        .screenBackground()
    }

    private func pair() async {
        isPairing = true
        defer { isPairing = false }
        if let result = await store.pairScreen(code: code) {
            partnership = result
            error = nil
        } else {
            error = "That code didn't match an active gym screen. Check the code in your partner dashboard."
        }
    }
}

/// The full-screen leaderboard shown on gym TVs. Rotates through the configured lifts and metrics.
struct GymDisplayView: View {
    let partnership: GymPartnership
    let gym: Gym
    let onExit: () -> Void

    @Environment(AppStore.self) private var store
    @State private var boardIndex = 0
    @State private var rows: [LeaderboardRow] = []
    @State private var challengeRows: [LeaderboardRow] = []

    private struct Board {
        let exerciseID: String
        let metric: LeaderboardMetric
    }

    private var boards: [Board] {
        var result: [Board] = []
        for id in partnership.screen.exerciseIDs {
            for metric in partnership.screen.metrics {
                result.append(Board(exerciseID: id, metric: metric))
            }
        }
        return result
    }

    private var current: Board {
        boards.isEmpty ? Board(exerciseID: "bench-press", metric: .absolute) : boards[boardIndex % boards.count]
    }

    private var accent: Color {
        guard partnership.tier.includesBranding, let hex = partnership.screen.accentHex,
              let value = UInt32(hex, radix: 16) else { return Theme.accent }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                     blue: Double(value & 0xFF) / 255)
    }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height
            VStack(alignment: .leading, spacing: 18) {
                topBar
                if wide {
                    HStack(alignment: .top, spacing: 18) {
                        boardPanel.frame(maxWidth: .infinity)
                        sidePanel.frame(width: geo.size.width * 0.32)
                    }
                } else {
                    boardPanel
                    sidePanel
                }
            }
            .padding(wide ? 32 : 18)
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task(id: boardIndex) {
            rows = await store.screenLeaderboard(gymID: gym.id, exerciseID: current.exerciseID, metric: current.metric)
        }
        .task {
            if let challenge = partnership.activeChallenge() {
                challengeRows = await store.screenLeaderboard(gymID: gym.id, exerciseID: challenge.exerciseID,
                                                              metric: challenge.metric, since: challenge.startsAt)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(max(5, partnership.screen.rotationSeconds)) * 1_000_000_000)
                withAnimation(.easeInOut) { boardIndex += 1 }
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle().fill(accent).frame(width: 9, height: 9)
                    Text("LIVE LEADERBOARD").font(.caption.weight(.black)).foregroundStyle(accent)
                }
                Text(gym.name.uppercased())
                    .font(.display(40))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Spacer()
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.display(36).monospacedDigit())
                    .foregroundStyle(.white)
            }
            Button(action: onExit) {
                Image(systemName: "xmark").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.35))
            }
            .accessibilityLabel("Exit screen mode")
        }
    }

    private var boardPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text((ExerciseLibrary.exercise(id: current.exerciseID)?.name ?? "").uppercased())
                    .font(.display(34))
                    .foregroundStyle(.white)
                Text(current.metric == .absolute ? "HEAVIEST" : "POUND FOR POUND")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent, in: Capsule())
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(rows.prefix(partnership.screen.rowsShown)) { row in
                    HStack(spacing: 14) {
                        Text("\(row.rank)")
                            .font(.display(26))
                            .foregroundStyle(row.rank == 1 ? Theme.onAccent : .white)
                            .frame(width: 44, height: 44)
                            .background(row.rank == 1 ? accent : Theme.surfaceRaised, in: Circle())
                        AvatarView(name: row.record.displayName, size: 40)
                        Text(row.record.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        Text(Format.record(row.record, unit: .kg))
                            .font(.subheadline)
                            .foregroundStyle(Theme.secondaryText)
                        Text(Format.score(row.score, metric: current.metric, unit: .kg))
                            .font(.stat(22).monospacedDigit())
                            .foregroundStyle(row.rank == 1 ? accent : .white)
                            .frame(minWidth: 100, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .id(boardIndex)
            .transition(.opacity)
            if boards.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<boards.count, id: \.self) { index in
                        Capsule()
                            .fill(index == boardIndex % boards.count ? accent : Theme.surfaceRaised)
                            .frame(width: index == boardIndex % boards.count ? 22 : 8, height: 6)
                    }
                }
            }
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let challenge = partnership.activeChallenge() {
                VStack(alignment: .leading, spacing: 8) {
                    Text("THIS MONTH'S CHALLENGE").font(.caption.weight(.black)).foregroundStyle(Theme.onAccent.opacity(0.7))
                    Text(challenge.title.uppercased()).font(.display(30)).foregroundStyle(Theme.onAccent)
                    Text("\(ExerciseLibrary.exercise(id: challenge.exerciseID)?.name ?? "") · \(challenge.metric.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.onAccent)
                    if let prize = challenge.prize {
                        Label(prize, systemImage: "gift.fill").font(.subheadline.weight(.bold)).foregroundStyle(Theme.onAccent)
                    }
                    let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: challenge.endsAt).day ?? 0)
                    Text("Ends in \(days) day\(days == 1 ? "" : "s")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.onAccent.opacity(0.75))
                    ForEach(challengeRows.prefix(3)) { row in
                        HStack {
                            Text("\(row.rank). \(row.record.displayName)").lineLimit(1)
                            Spacer()
                            Text(Format.score(row.score, metric: challenge.metric, unit: .kg))
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.onAccent)
                    }
                }
                .card(accent, padding: 18)
            }
            HStack(spacing: 14) {
                if let qr = QRCode.image(for: "https://liftbros.app/join?gym=\(gym.id)") {
                    Image(uiImage: qr)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 96, height: 96)
                        .padding(6)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("GET ON THE BOARD").font(.display(22)).foregroundStyle(.white)
                    Text("Scan to download LiftBros and log your lifts. Honour system, every set counts.")
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .card()
        }
    }
}

enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
