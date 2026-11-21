import SwiftUI
import Observation

@Observable
final class RestTimer {
    var endDate: Date?
    var defaultSeconds = 120

    func start(seconds: Int) {
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
    }

    func add(seconds: Int) {
        guard let endDate else { return }
        self.endDate = max(endDate, Date()).addingTimeInterval(TimeInterval(seconds))
    }

    func stop() { endDate = nil }
}

struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        if let end = timer.endDate {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int(end.timeIntervalSince(context.date).rounded(.up)))
                HStack(spacing: 16) {
                    Image(systemName: remaining == 0 ? "bell.fill" : "timer")
                        .foregroundStyle(remaining == 0 ? Theme.teal : Theme.accent)
                    Text(remaining == 0 ? "Rest over — next set!" : String(format: "Rest %ld:%02ld", remaining / 60, remaining % 60))
                        .font(.headline.monospacedDigit())
                    Spacer()
                    Button("+30s") { timer.add(seconds: 30) }
                        .buttonStyle(.bordered)
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Stop rest timer")
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Theme.surfaceRaised)
                .sensoryFeedback(.success, trigger: remaining == 0)
            }
        }
    }
}
