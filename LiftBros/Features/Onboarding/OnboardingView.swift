import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store

    private enum Step: Int, CaseIterable {
        case welcome, account, gym, body, privacy
    }

    @State private var step: Step = .welcome
    @State private var displayName = ""
    @State private var username = ""
    @State private var gymID: String?
    @State private var unit: WeightUnit = .kg
    @State private var sex: Sex = .male
    @State private var bodyweight: Double?
    @State private var heightCm: Double?
    @State private var bodyFat: Double?
    @State private var birthYear = Calendar.current.component(.year, from: Date()) - 25
    @State private var yearsLifting = 1.0
    @State private var trainingDays = 3
    @State private var goal: TrainingGoal = .strength
    @State private var privacy = PrivacySettings()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if step != .welcome {
                    ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                        .tint(Theme.accent)
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                content
                footer
            }
            .screenBackground()
            .navigationTitle(title.uppercased())
            .navigationBarTitleDisplayMode(.inline)
            .animation(.default, value: step)
        }
    }

    private var title: String {
        switch step {
        case .welcome: return ""
        case .account: return "Your account"
        case .gym: return "Your gym"
        case .body: return "About you"
        case .privacy: return "Privacy"
        }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcome
        case .account: account
        case .gym: gymStep
        case .body: bodyStep
        case .privacy: privacyStep
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 22) {
            Text("LIFTBROS · WORCESTERSHIRE")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 12)
            Text("LOG IT.\nRANK IT.\nPROVE IT.")
                .font(.display(56))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .lineSpacing(-8)
            HStack(spacing: -18) {
                welcomeCard(symbol: "dumbbell.fill", title: "Log", value: "120 × 5", color: Theme.lavender)
                    .rotationEffect(.degrees(-8))
                welcomeCard(symbol: "trophy.fill", title: "Your gym", value: "#1", color: Theme.accent)
                    .zIndex(1)
                    .scaleEffect(1.08)
                welcomeCard(symbol: "checkmark.seal.fill", title: "National", value: "Top 100", color: Theme.teal)
                    .rotationEffect(.degrees(8))
            }
            .padding(.vertical, 10)
            VStack(alignment: .leading, spacing: 12) {
                feature("hand.raised.fill", "Gym leaderboards on the honour system: every set counts")
                feature("checkmark.seal.fill", "Make the national top 100 with video evidence")
                feature("scalemass.fill", "Pound-for-pound rankings that factor in bodyweight")
                feature("lock.fill", "You choose who sees your progress")
            }
            .padding(.horizontal, 28)
            Spacer()
        }
    }

    private func welcomeCard(symbol: String, title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.onAccent)
            Spacer()
            Text(title.uppercased()).font(.caption2.weight(.black)).foregroundStyle(Theme.onAccent.opacity(0.7))
            Text(value).font(.display(24)).foregroundStyle(Theme.onAccent).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(14)
        .frame(width: 118, height: 150, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 6)
    }

    private func feature(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            Text(text).font(.subheadline).foregroundStyle(.white)
        }
    }

    private var account: some View {
        Form {
            Section {
                TextField("Display name", text: $displayName)
                    .textContentType(.name)
                TextField("Username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: username) { _, newValue in
                        let cleaned = String(newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }.prefix(20))
                        if cleaned != newValue { username = cleaned }
                    }
            } footer: {
                Text("Your name and username appear on leaderboards.")
            }
            Section("Units") {
                Picker("Weight unit", selection: $unit) {
                    Text("Kilograms").tag(WeightUnit.kg)
                    Text("Pounds").tag(WeightUnit.lb)
                }
                .pickerStyle(.segmented)
            }
        }
        .darkList()
    }

    private var gymStep: some View {
        GymPickerList(selection: $gymID)
    }

    private var bodyStep: some View {
        Form {
            Section {
                Picker("Sex", selection: $sex) {
                    ForEach(Sex.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                DecimalField(title: "Bodyweight", value: $bodyweight, suffix: unit.symbol, prompt: "Required")
                DecimalField(title: "Height", value: $heightCm, suffix: "cm", prompt: "Optional")
                DecimalField(title: "Body fat", value: $bodyFat, suffix: "%", prompt: "Optional")
                Picker("Year of birth", selection: $birthYear) {
                    let thisYear = Calendar.current.component(.year, from: Date())
                    ForEach((thisYear - 90)...(thisYear - 13), id: \.self) { Text(String($0)).tag($0) }
                }
            } header: {
                Text("Body stats")
            } footer: {
                Text("Sex and bodyweight decide your division and pound-for-pound score. Body stats stay private unless you choose otherwise.")
            }
            Section("Training") {
                Stepper(value: $yearsLifting, in: 0...40, step: 0.5) {
                    LabeledContent("Time lifting", value: yearsLabel(yearsLifting))
                }
                Stepper(value: $trainingDays, in: 1...7) {
                    LabeledContent("Days per week", value: "\(trainingDays)")
                }
                Picker("Main goal", selection: $goal) {
                    ForEach(TrainingGoal.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
        }
        .darkList()
    }

    private var privacyStep: some View {
        PrivacySettingsForm(privacy: $privacy)
    }

    // MARK: Footer & navigation

    private var footer: some View {
        HStack(spacing: 10) {
            if step != .welcome {
                Button {
                    step = Step(rawValue: step.rawValue - 1) ?? .welcome
                } label: {
                    Image(systemName: "chevron.left").font(.headline)
                }
                .buttonStyle(SecondaryButtonStyle())
                .frame(width: 64)
            }
            Button(step == .privacy ? "Start lifting" : (step == .welcome ? "Start building your strength" : "Next")) {
                advance()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.45)
        }
        .padding()
        .background(Theme.background)
    }

    private var canAdvance: Bool {
        switch step {
        case .welcome: return true
        case .account:
            return !displayName.trimmingCharacters(in: .whitespaces).isEmpty && username.count >= 3
        case .gym: return gymID != nil
        case .body:
            guard let bodyweight else { return false }
            let kg = unit.toKg(bodyweight)
            return (30...300).contains(kg)
        case .privacy: return true
        }
    }

    private func advance() {
        guard step == .privacy else {
            step = Step(rawValue: step.rawValue + 1) ?? .privacy
            return
        }
        guard let gymID, let bodyweight else { return }
        let profile = UserProfile(
            displayName: displayName.trimmingCharacters(in: .whitespaces),
            username: username,
            gymID: gymID,
            sex: sex,
            birthYear: birthYear,
            heightCm: heightCm,
            bodyweightKg: unit.toKg(bodyweight),
            bodyFatPercent: bodyFat,
            yearsLifting: yearsLifting,
            trainingDaysPerWeek: trainingDays,
            goal: goal,
            unit: unit,
            privacy: privacy)
        store.completeOnboarding(profile)
    }
}

func yearsLabel(_ years: Double) -> String {
    if years < 1 { return years == 0 ? "Just starting" : "6 months" }
    let formatted = years.formatted(.number.precision(.fractionLength(0...1)))
    return years == 1 ? "1 year" : "\(formatted) years"
}

/// Searchable list of Worcestershire gyms, grouped by district.
struct GymPickerList: View {
    @Environment(AppStore.self) private var store
    @Binding var selection: String?
    @State private var search = ""

    private var filtered: [Gym] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return store.gyms }
        let compactQuery = query.replacingOccurrences(of: " ", with: "")
        return store.gyms.filter {
            $0.name.lowercased().contains(query) || $0.city.lowercased().contains(query)
                || $0.brand.lowercased().contains(query)
                || (!$0.postcode.isEmpty && $0.postcode.lowercased().replacingOccurrences(of: " ", with: "").hasPrefix(compactQuery))
                || $0.postcodeArea.lowercased() == query
        }
    }

    var body: some View {
        List {
            ForEach(District.allCases, id: \.self) { district in
                let gyms = filtered.filter { $0.district == district }.sorted { $0.name < $1.name }
                if !gyms.isEmpty {
                    Section(district.displayName) {
                        ForEach(gyms) { gym in
                            Button {
                                selection = gym.id
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(gym.name).foregroundStyle(.white)
                                        Text("\(gym.subtitle) · \(gym.kind.displayName)")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                    }
                                    Spacer()
                                    if selection == gym.id {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section {
                Text("LiftBros is launching across Worcestershire first. Gym missing or closed? Let us know and we'll update the list.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .darkList()
        .searchable(text: $search, prompt: "Search gym, town or postcode")
    }
}

/// Shared privacy controls used in onboarding and the profile tab.
struct PrivacySettingsForm: View {
    @Binding var privacy: PrivacySettings

    var body: some View {
        Form {
            PrivacySettingsSection(privacy: $privacy)
        }
        .darkList()
    }
}

struct PrivacySettingsSection: View {
    @Binding var privacy: PrivacySettings

    var body: some View {
        Section {
            Toggle("Appear on leaderboards", isOn: $privacy.showOnLeaderboards)
            Picker("Who can see my progress", selection: $privacy.progressVisibility) {
                ForEach(Audience.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            Picker("Who can see my body stats", selection: $privacy.bodyStatsVisibility) {
                ForEach(Audience.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
        } header: {
            Text("Privacy")
        } footer: {
            Text("Leaderboards show your name, best lift and the bodyweight it was lifted at. Progress means your workout history and charts. Body stats are body fat, height and age.")
        }
    }
}
