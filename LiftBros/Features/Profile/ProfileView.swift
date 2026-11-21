import StoreKit
import SwiftUI

struct ProfileView: View {
    @Binding var showPaywall: Bool
    @Binding var showGymScreen: Bool

    @Environment(AppStore.self) private var store
    @State private var showEdit = false
    @State private var confirmReset = false
    @State private var showManageSubscription = false

    var body: some View {
        NavigationStack {
            if let profile = store.profile {
                List {
                    Section {
                        header(profile)
                        planCard
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))

                    bodyStats(profile)
                    PrivacySettingsSection(privacy: Binding(
                        get: { store.profile?.privacy ?? PrivacySettings() },
                        set: { newValue in store.updateProfile { $0.privacy = newValue } }))
                    preferences
                    Section("Tools") {
                        NavigationLink { PlateCalculatorView() } label: {
                            Label("Plate calculator", systemImage: "circle.grid.2x1.fill")
                        }
                        NavigationLink { OneRepMaxCalculatorView() } label: {
                            Label("1RM calculator", systemImage: "function")
                        }
                        Button {
                            showGymScreen = true
                        } label: {
                            Label("Gym screen mode", systemImage: "tv")
                        }
                    }
                    Section("Your data") {
                        if store.isPro {
                            NavigationLink { ExportDataView() } label: {
                                Label("Export workouts (CSV)", systemImage: "square.and.arrow.up")
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    Label("Export workouts (CSV)", systemImage: "square.and.arrow.up")
                                    Spacer()
                                    ProBadge()
                                }
                            }
                        }
                        Button("Delete all my data", role: .destructive) { confirmReset = true }
                    }
                    Section {
                        NavigationLink { GymPartnersInfoView() } label: {
                            Label("LiftBros for gyms", systemImage: "building.2")
                        }
                        NavigationLink { HowRankingWorksView() } label: {
                            Label("How rankings & evidence work", systemImage: "info.circle")
                        }
                    } footer: {
                        Text("LiftBros \(Bundle.main.appVersion)")
                    }
                }
                .darkList()
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $showEdit) {
                    EditProfileView(profile: profile)
                }
                .manageSubscriptionsSheet(isPresented: $showManageSubscription)
                .confirmationDialog("Delete all data?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Delete everything", role: .destructive) { store.resetAllData() }
                } message: {
                    Text("Your profile, workouts, body stats and evidence videos will be permanently removed from this device.")
                }
            }
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("PROFILE").font(.display(38))
                Spacer()
                Button("Edit") { showEdit = true }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.onAccent)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.accent, in: Capsule())
                    .buttonStyle(.plain)
            }
            HStack(spacing: 14) {
                AvatarView(name: profile.displayName, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.displayName.uppercased()).font(.display(26))
                        if store.isPro { ProBadge() }
                    }
                    Text("@\(profile.username)").foregroundStyle(Theme.secondaryText)
                    if let gym = store.currentGym { GymCaption(name: gym.name) }
                }
            }
            if !profile.bio.isEmpty {
                Text(profile.bio).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var planCard: some View {
        if store.isPro {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Theme.onAccent, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("PRO MEMBER").font(.display(22))
                    Text("Unlimited evidence, priority review, all-time charts")
                        .font(.caption)
                }
                Spacer()
                if store.subscriptions.storeAvailable {
                    Button("Manage") { showManageSubscription = true }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.plain)
                }
            }
            .foregroundStyle(Theme.onAccent)
            .card(Theme.accent, padding: 14)
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 48, height: 48)
                        .background(Theme.accent, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GO PRO").font(.display(22)).foregroundStyle(.white)
                        Text("From \(store.subscriptions.displayPrice(.yearly))/year. Unlimited evidence, head-to-head and more.")
                            .font(.caption)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Theme.accent)
                }
                .card(padding: 14)
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).stroke(Theme.accent.opacity(0.5)))
            }
            .buttonStyle(.plain)
        }
    }

    private func bodyStats(_ profile: UserProfile) -> some View {
        let unit = profile.unit
        return Section("Body & training") {
            LabeledContent("Bodyweight", value: Format.weight(profile.bodyweightKg, unit))
            if let bodyFat = profile.bodyFatPercent {
                LabeledContent("Body fat", value: "\(bodyFat.formatted(.number.precision(.fractionLength(0...1))))%")
            }
            if let lean = profile.leanMassKg {
                LabeledContent("Lean mass", value: Format.weight(lean, unit))
            }
            if let height = profile.heightCm {
                LabeledContent("Height", value: "\(Int(height)) cm")
            }
            if let bmi = profile.bmi {
                LabeledContent("BMI", value: bmi.formatted(.number.precision(.fractionLength(1))))
            }
            if let age = profile.age() {
                LabeledContent("Age", value: "\(age)")
            }
            LabeledContent("Sex / division", value: profile.sex.displayName)
            LabeledContent("Lifting for", value: "\(yearsLabel(profile.yearsLifting)) (\(profile.experienceLabel))")
            LabeledContent("Trains", value: "\(profile.trainingDaysPerWeek) days a week")
            LabeledContent("Goal", value: profile.goal.displayName)
        }
    }

    private var preferences: some View {
        Section("Preferences") {
            Picker("Weight unit", selection: Binding(
                get: { store.profile?.unit ?? .kg },
                set: { newValue in store.updateProfile { $0.unit = newValue } })) {
                Text("Kilograms").tag(WeightUnit.kg)
                Text("Pounds").tag(WeightUnit.lb)
            }
            if store.isPro {
                Picker("Default rest", selection: Binding(get: { store.restSeconds },
                                                          set: { store.setRestSeconds($0) })) {
                    ForEach([60, 90, 120, 150, 180, 240, 300], id: \.self) { seconds in
                        Text(seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60):\(String(format: "%02ld", seconds % 60))")
                            .tag(seconds)
                    }
                }
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        Text("Default rest").foregroundStyle(.white)
                        Spacer()
                        Text("2 min").foregroundStyle(Theme.secondaryText)
                        ProBadge()
                    }
                }
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

/// Pro: exports every logged set as a CSV file.
struct ExportDataView: View {
    @Environment(AppStore.self) private var store
    @State private var fileURL: URL?
    @State private var error: String?

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "tablecells").font(.system(size: 52)).foregroundStyle(Theme.accent)
            Text("EXPORT YOUR DATA").font(.display(30))
            Text("Every set you've logged (date, gym, exercise, weight, reps, RPE, bodyweight, e1RM and evidence status) as a spreadsheet-ready CSV.")
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
            if let fileURL {
                ShareLink(item: fileURL) {
                    Label("Share CSV", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if let error {
                Text(error).foregroundStyle(.red)
            } else {
                ProgressView()
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .task {
            do {
                fileURL = try store.exportCSV()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

/// Explains the B2B offer for gym owners.
struct GymPartnersInfoView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("LIFTBROS FOR GYMS").font(.display(36))
                Text("Put your members' lifts on the big screen. A live, honour-system leaderboard on your gym's TVs gets members competing, coming back, and bringing friends.")
                    .foregroundStyle(Theme.secondaryText)
                ForEach(GymPartnerTier.allCases, id: \.self) { tier in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(tier.displayName.uppercased()).font(.display(26))
                            Spacer()
                            Text(tier.monthlyPriceGBP.map { "£\($0)/mo" } ?? "Let's talk")
                                .font(.stat(18))
                                .foregroundStyle(Theme.accent)
                        }
                        ForEach(features(for: tier), id: \.self) { feature in
                            Label(feature, systemImage: "checkmark")
                                .font(.subheadline)
                        }
                    }
                    .card()
                }
                Text("Screens run on any iPad, Apple TV (via AirPlay) or smart TV. Staff pair a screen with a code from the partner dashboard. Already a partner? Open Profile → Gym screen mode on the screen device.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(18)
        }
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private func features(for tier: GymPartnerTier) -> [String] {
        switch tier {
        case .screen:
            return ["1 leaderboard screen", "Rotating gym boards for the big lifts", "QR code so members can join"]
        case .screenPlus:
            return ["Up to \(tier.maxScreens) screens", "Your branding and colours", "Monthly challenges with prizes",
                    "Member engagement analytics"]
        case .network:
            return ["Every site in your group", "Gym-vs-gym competitions", "Group-wide analytics", "Dedicated support"]
        }
    }
}

struct EditProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UserProfile
    @State private var bodyweight: Double?
    @State private var gymID: String?

    init(profile: UserProfile) {
        _draft = State(initialValue: profile)
        _bodyweight = State(initialValue: (profile.unit.fromKg(profile.bodyweightKg) * 10).rounded() / 10)
        _gymID = State(initialValue: profile.gymID)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Display name", text: $draft.displayName)
                    TextField("Bio", text: $draft.bio, axis: .vertical)
                        .lineLimit(1...4)
                }
                Section("Gym") {
                    NavigationLink {
                        GymPickerList(selection: $gymID)
                            .navigationTitle("Choose gym")
                    } label: {
                        LabeledContent("Home gym", value: store.gym(id: gymID ?? "")?.name ?? "Choose")
                    }
                }
                Section {
                    Picker("Sex", selection: $draft.sex) {
                        ForEach(Sex.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    DecimalField(title: "Bodyweight", value: $bodyweight, suffix: draft.unit.symbol)
                    DecimalField(title: "Height", value: $draft.heightCm, suffix: "cm", prompt: "Optional")
                    DecimalField(title: "Body fat", value: $draft.bodyFatPercent, suffix: "%", prompt: "Optional")
                    Picker("Year of birth", selection: Binding(
                        get: { draft.birthYear ?? 0 },
                        set: { draft.birthYear = $0 == 0 ? nil : $0 })) {
                        Text("Not set").tag(0)
                        let thisYear = Calendar.current.component(.year, from: Date())
                        ForEach((thisYear - 90)...(thisYear - 13), id: \.self) { Text(String($0)).tag($0) }
                    }
                } header: {
                    Text("Body stats")
                } footer: {
                    Text("Changing your bodyweight adds an entry to your bodyweight history. Past lifts keep the bodyweight they were lifted at.")
                }
                Section("Training") {
                    Stepper(value: $draft.yearsLifting, in: 0...40, step: 0.5) {
                        LabeledContent("Time lifting", value: yearsLabel(draft.yearsLifting))
                    }
                    Stepper(value: $draft.trainingDaysPerWeek, in: 1...7) {
                        LabeledContent("Days per week", value: "\(draft.trainingDaysPerWeek)")
                    }
                    Picker("Main goal", selection: $draft.goal) {
                        ForEach(TrainingGoal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                }
            }
            .darkList()
            .navigationTitle("EDIT PROFILE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.bold)
                        .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        guard let bodyweight else { return false }
        return !draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty
            && (30...300).contains(draft.unit.toKg(bodyweight))
    }

    private func save() {
        guard let bodyweight else { return }
        var updated = draft
        updated.displayName = draft.displayName.trimmingCharacters(in: .whitespaces)
        let newKg = draft.unit.toKg(bodyweight)
        // Avoid logging a fake bodyweight change from kg/lb rounding.
        if abs(newKg - (store.profile?.bodyweightKg ?? 0)) > 0.05 { updated.bodyweightKg = newKg }
        let gymChanged = gymID != nil && gymID != store.profile?.gymID
        if let gymID { updated.gymID = gymID }
        store.saveProfile(updated)
        if gymChanged, let gymID { store.chooseGym(gymID) }
        dismiss()
    }
}
