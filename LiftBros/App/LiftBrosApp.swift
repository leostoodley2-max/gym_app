import SwiftUI

@main
struct LiftBrosApp: App {
    @State private var store = DemoDirector.shared.makeStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
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
            } else if store.needsGymSelection {
                ChooseGymAgainView()
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
                Task {
                    await store.refreshPendingVerifications()
                    await store.subscriptions.refreshEntitlements()
                }
            }
        }
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store
    @State private var tab: AppTab = .train
    @State private var showPaywall = false
    @State private var showGymScreen = false
    private let demo = DemoDirector.shared

    var body: some View {
        TabView(selection: $tab) {
            WorkoutHomeView(showPaywall: $showPaywall)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.train)
            LeaderboardView(showPaywall: $showPaywall)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.rankings)
            ProgressDashboardView(showPaywall: $showPaywall)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.progress)
            ProfileView(showPaywall: $showPaywall, showGymScreen: $showGymScreen)
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.profile)
        }
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selection: $tab)
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showGymScreen) {
            GymScreenFlow()
        }
        .onChange(of: demo.tab, initial: true) { _, newValue in
            if demo.isEnabled { tab = newValue }
        }
        .onChange(of: demo.showPaywall) { _, show in
            if demo.isEnabled { showPaywall = show }
        }
        .onChange(of: demo.showGymScreen) { _, show in
            if demo.isEnabled { showGymScreen = show }
        }
    }
}

/// Shown to existing users whose saved gym isn't in the (now Worcestershire) gym directory.
struct ChooseGymAgainView: View {
    @Environment(AppStore.self) private var store
    @State private var gymID: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PICK YOUR GYM")
                        .font(.display(34))
                    Text("LiftBros now covers every gym in Worcestershire. Choose your home gym to see your local leaderboard.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                GymPickerList(selection: $gymID)
                Button("Save gym") {
                    if let gymID { store.chooseGym(gymID) }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(gymID == nil)
                .opacity(gymID == nil ? 0.5 : 1)
                .padding()
            }
            .screenBackground()
        }
    }
}
