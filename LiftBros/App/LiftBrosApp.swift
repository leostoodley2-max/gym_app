import SwiftUI

@main
struct LiftBrosApp: App {
    @State private var store = DemoDirector.shared.makeStore()

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
        .task {
            DemoDirector.shared.start()
            await store.refreshPendingVerifications()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.refreshPendingVerifications() }
            }
        }
    }
}

struct MainTabView: View {
    @State private var tab: AppTab = .train
    private let demo = DemoDirector.shared

    var body: some View {
        TabView(selection: $tab) {
            WorkoutHomeView()
                .tabItem { Label("Train", systemImage: "dumbbell.fill") }
                .tag(AppTab.train)
            LeaderboardView()
                .tabItem { Label("Rankings", systemImage: "trophy.fill") }
                .tag(AppTab.rankings)
            ProgressDashboardView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(AppTab.profile)
        }
        .onChange(of: demo.tab, initial: true) { _, newValue in
            if demo.isEnabled { tab = newValue }
        }
    }
}
