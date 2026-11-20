import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @State private var showEdit = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            if let profile = store.profile {
                List {
                    header(profile)
                    bodyStats(profile)
                    PrivacySettingsSection(privacy: Binding(
                        get: { store.profile?.privacy ?? PrivacySettings() },
                        set: { newValue in store.updateProfile { $0.privacy = newValue } }))
                    Section("Preferences") {
                        Picker("Weight unit", selection: Binding(
                            get: { store.profile?.unit ?? .kg },
                            set: { newValue in store.updateProfile { $0.unit = newValue } })) {
                            Text("Kilograms").tag(WeightUnit.kg)
                            Text("Pounds").tag(WeightUnit.lb)
                        }
                    }
                    Section("Tools") {
                        NavigationLink { PlateCalculatorView() } label: {
                            Label("Plate calculator", systemImage: "circle.grid.2x1.fill")
                        }
                        NavigationLink { OneRepMaxCalculatorView() } label: {
                            Label("1RM calculator", systemImage: "function")
                        }
                    }
                    Section("About") {
                        NavigationLink { HowRankingWorksView() } label: {
                            Label("How rankings & verification work", systemImage: "info.circle")
                        }
                    }
                    Section {
                        Button("Delete all my data", role: .destructive) { confirmReset = true }
                    } footer: {
                        Text("LiftBros \(Bundle.main.appVersion)")
                    }
                }
                .navigationTitle("Profile")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") { showEdit = true }
                    }
                }
                .sheet(isPresented: $showEdit) {
                    EditProfileView(profile: profile)
                }
                .confirmationDialog("Delete all data?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Delete everything", role: .destructive) { store.resetAllData() }
                } message: {
                    Text("Your profile, workouts, body stats and proof videos will be permanently removed from this device.")
                }
            }
        }
    }

    private func header(_ profile: UserProfile) -> some View {
        Section {
            HStack(spacing: 16) {
                AvatarView(name: profile.displayName, size: 72)
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.displayName).font(.title2.weight(.bold))
                    Text("@\(profile.username)").foregroundStyle(.secondary)
                    if let gym = store.currentGym {
                        Label(gym.name, systemImage: "mappin.and.ellipse").font(.caption)
                    }
                }
            }
            .padding(.vertical, 4)
            if !profile.bio.isEmpty {
                Text(profile.bio).font(.subheadline)
            }
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
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
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
            .navigationTitle("Edit profile")
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
        if let gymID { updated.gymID = gymID }
        store.saveProfile(updated)
        dismiss()
    }
}
