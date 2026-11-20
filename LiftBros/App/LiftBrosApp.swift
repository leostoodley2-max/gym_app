import SwiftUI

@main
struct LiftBrosApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
        }
    }
}

struct RootView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if store.profile == nil {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
        .task { await store.refreshPendingVerifications() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.refreshPendingVerifications() }
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            WorkoutHomeView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
            LeaderboardView()
                .tabItem { Label("Rankings", systemImage: "trophy.fill") }
            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
    }
}
