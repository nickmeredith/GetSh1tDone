import SwiftUI

// MARK: - Coach config types (Review / Prepare: day of week + time; Priorities / Goals / Clean up: frequency)

/// Day of week: 0 = every day, 1 = Sunday … 7 = Saturday (Calendar.weekday).
struct PeriodSchedule: Codable, Equatable {
    var isEnabled: Bool
    var dayOfWeek: Int  // 0 = every day, 1–7 = Sunday–Saturday
    var timeOfDay: Date // time only (stored as Date with reference date)
    
    static let referenceDate: Date = {
        var c = Calendar.current
        c.timeZone = TimeZone.current
        return c.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 9, minute: 0)) ?? Date()
    }()
    
    static func defaultForPeriod(_ period: ReviewPreparePeriod) -> PeriodSchedule {
        let day: Int = period == .day ? 0 : 1 // day = every day; week = Sunday
        return PeriodSchedule(isEnabled: true, dayOfWeek: day, timeOfDay: Self.referenceDate)
    }
    
    /// Backward compatibility: decode old config without isEnabled (treat as enabled).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = (try? c.decode(Bool.self, forKey: .isEnabled)) ?? true
        dayOfWeek = try c.decode(Int.self, forKey: .dayOfWeek)
        timeOfDay = try c.decode(Date.self, forKey: .timeOfDay)
    }
    
    init(isEnabled: Bool, dayOfWeek: Int, timeOfDay: Date) {
        self.isEnabled = isEnabled
        self.dayOfWeek = dayOfWeek
        self.timeOfDay = timeOfDay
    }
    
    private enum CodingKeys: String, CodingKey {
        case isEnabled, dayOfWeek, timeOfDay
    }
}

enum ReviewPreparePeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case quarter = "Quarter"
    var id: String { rawValue }
}

/// Review or Prepare config: one schedule per period (day, week, month, quarter).
struct ReviewPrepareConfig: Codable, Equatable {
    var day: PeriodSchedule
    var week: PeriodSchedule
    var month: PeriodSchedule
    var quarter: PeriodSchedule
    
    static let `default` = ReviewPrepareConfig(
        day: PeriodSchedule.defaultForPeriod(.day),
        week: PeriodSchedule.defaultForPeriod(.week),
        month: PeriodSchedule.defaultForPeriod(.month),
        quarter: PeriodSchedule.defaultForPeriod(.quarter)
    )
}

enum CoachFrequency: String, CaseIterable, Identifiable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case quarterly = "Quarterly"
    var id: String { rawValue }
}

/// Priorities / Goals / Clean up: enabled toggle + frequency. Stored in UserDefaults.
struct FrequencyConfig: Codable, Equatable {
    var isEnabled: Bool
    var frequency: CoachFrequency
    
    static let `default` = FrequencyConfig(isEnabled: true, frequency: .weekly)
}

// MARK: - App config keys (UserDefaults)

/// Central list of UserDefaults keys for all non-Reminders config.
/// Use these constants instead of string literals so keys stay in one place and are easy to change.
enum AppConfigKeys {
    /// Priorities list (encoded [Priority]) in PrioritiesView.
    static let prioritiesList = "priorities"
    /// Last priority review date in PrioritiesView.
    static let lastPriorityReview = "lastPriorityReview"
}

// MARK: - Coach config storage (UserDefaults)

/// All Coach config is persisted in UserDefaults under the keys below.
/// Review and Prepare: JSON-encoded ReviewPrepareConfig (day/week/month/quarter each with isEnabled, dayOfWeek, timeOfDay).
/// Priorities, Goals, Clean up: JSON-encoded FrequencyConfig (isEnabled + frequency).
private enum CoachConfigKeys {
    static let review = "coachReviewConfig"
    static let prepare = "coachPrepareConfig"
    static let priorities = "coachPrioritiesConfig"
    static let goals = "coachGoalsConfig"
    static let cleanUp = "coachCleanUpConfig"
}

struct CoachConfigStorage {
    static func loadReview() -> ReviewPrepareConfig {
        guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.review),
              let decoded = try? JSONDecoder().decode(ReviewPrepareConfig.self, from: data) else {
            return .default
        }
        return decoded
    }
    
    static func saveReview(_ config: ReviewPrepareConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: CoachConfigKeys.review)
        }
    }
    
    static func loadPrepare() -> ReviewPrepareConfig {
        guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.prepare),
              let decoded = try? JSONDecoder().decode(ReviewPrepareConfig.self, from: data) else {
            return .default
        }
        return decoded
    }
    
    static func savePrepare(_ config: ReviewPrepareConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: CoachConfigKeys.prepare)
        }
    }
    
    static func loadPriorities() -> FrequencyConfig {
        guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.priorities),
              let decoded = try? JSONDecoder().decode(FrequencyConfig.self, from: data) else {
            return .default
        }
        return decoded
    }
    
    static func savePriorities(_ config: FrequencyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: CoachConfigKeys.priorities)
        }
    }
    
    static func loadGoals() -> FrequencyConfig {
        guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.goals),
              let decoded = try? JSONDecoder().decode(FrequencyConfig.self, from: data) else {
            return .default
        }
        return decoded
    }
    
    static func saveGoals(_ config: FrequencyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: CoachConfigKeys.goals)
        }
    }
    
    static func loadCleanUp() -> FrequencyConfig {
        guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.cleanUp),
              let decoded = try? JSONDecoder().decode(FrequencyConfig.self, from: data) else {
            return .default
        }
        return decoded
    }
    
    static func saveCleanUp(_ config: FrequencyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: CoachConfigKeys.cleanUp)
        }
    }
}

// MARK: - Settings main view

struct SettingsView: View {
    @ObservedObject var remindersManager: RemindersManager
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: DelegatesSettingsView(remindersManager: remindersManager)) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Delegates")
                    }
                }
                
                Section(header: Text("Coach")) {
                    NavigationLink(destination: ReviewConfigView()) {
                        Label("Review", systemImage: "arrow.clockwise.circle.fill")
                    }
                    NavigationLink(destination: PrepareConfigView()) {
                        Label("Prepare", systemImage: "forward.circle.fill")
                    }
                    NavigationLink(destination: PrioritiesConfigView()) {
                        Label("Priorities", systemImage: "star.circle.fill")
                    }
                    NavigationLink(destination: GoalsConfigView()) {
                        Label("Goals", systemImage: "target")
                    }
                    NavigationLink(destination: CleanUpConfigView()) {
                        Label("Clean up", systemImage: "trash.circle.fill")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

// MARK: - Review config (Day / Week / Month / Quarter → Enable + Day of week + Time of day)

struct ReviewConfigView: View {
    @State private var config: ReviewPrepareConfig = CoachConfigStorage.loadReview()
    
    var body: some View {
        Form {
            ForEach(ReviewPreparePeriod.allCases) { period in
                Section(header: Text(period.rawValue)) {
                    scheduleBinding(for: period)
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            CoachConfigStorage.saveReview(newValue)
        }
    }
    
    @ViewBuilder
    private func scheduleBinding(for period: ReviewPreparePeriod) -> some View {
        let binding = binding(for: period)
        Toggle("Enable", isOn: binding.isEnabled)
        DayOfWeekPicker(dayOfWeek: binding.dayOfWeek, showEveryDay: period == .day)
        DatePicker("Time of day", selection: binding.timeOfDay, displayedComponents: [.hourAndMinute])
    }
    
    private func binding(for period: ReviewPreparePeriod) -> Binding<PeriodSchedule> {
        switch period {
        case .day: return $config.day
        case .week: return $config.week
        case .month: return $config.month
        case .quarter: return $config.quarter
        }
    }
}

// MARK: - Prepare config (same as Review)

struct PrepareConfigView: View {
    @State private var config: ReviewPrepareConfig = CoachConfigStorage.loadPrepare()
    
    var body: some View {
        Form {
            ForEach(ReviewPreparePeriod.allCases) { period in
                Section(header: Text(period.rawValue)) {
                    scheduleBinding(for: period)
                }
            }
        }
        .navigationTitle("Prepare")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            CoachConfigStorage.savePrepare(newValue)
        }
    }
    
    @ViewBuilder
    private func scheduleBinding(for period: ReviewPreparePeriod) -> some View {
        let binding = binding(for: period)
        Toggle("Enable", isOn: binding.isEnabled)
        DayOfWeekPicker(dayOfWeek: binding.dayOfWeek, showEveryDay: period == .day)
        DatePicker("Time of day", selection: binding.timeOfDay, displayedComponents: [.hourAndMinute])
    }
    
    private func binding(for period: ReviewPreparePeriod) -> Binding<PeriodSchedule> {
        switch period {
        case .day: return $config.day
        case .week: return $config.week
        case .month: return $config.month
        case .quarter: return $config.quarter
        }
    }
}

// MARK: - Day of week picker (0 = every day, 1–7 = Sunday–Saturday)

private struct DayOfWeekPicker: View {
    @Binding var dayOfWeek: Int
    let showEveryDay: Bool
    
    private static let weekdays: [(Int, String)] = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    var body: some View {
        Picker("Day of week", selection: $dayOfWeek) {
            if showEveryDay {
                Text("Every day").tag(0)
            }
            ForEach(Self.weekdays, id: \.0) { value, label in
                Text(label).tag(value)
            }
        }
    }
}

// MARK: - Priorities / Goals / Clean up config (Enable + frequency)

struct PrioritiesConfigView: View {
    @State private var config: FrequencyConfig = CoachConfigStorage.loadPriorities()
    
    var body: some View {
        Form {
            Section(header: Text("Priorities prompts")) {
                Toggle("Enable", isOn: $config.isEnabled)
                Picker("Frequency", selection: $config.frequency) {
                    ForEach(CoachFrequency.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Priorities")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            CoachConfigStorage.savePriorities(newValue)
        }
    }
}

struct GoalsConfigView: View {
    @State private var config: FrequencyConfig = CoachConfigStorage.loadGoals()
    
    var body: some View {
        Form {
            Section(header: Text("Goals prompts")) {
                Toggle("Enable", isOn: $config.isEnabled)
                Picker("Frequency", selection: $config.frequency) {
                    ForEach(CoachFrequency.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            CoachConfigStorage.saveGoals(newValue)
        }
    }
}

struct CleanUpConfigView: View {
    @State private var config: FrequencyConfig = CoachConfigStorage.loadCleanUp()
    
    var body: some View {
        Form {
            Section(header: Text("Clean up prompts")) {
                Toggle("Enable", isOn: $config.isEnabled)
                Picker("Frequency", selection: $config.frequency) {
                    ForEach(CoachFrequency.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .navigationTitle("Clean up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            CoachConfigStorage.saveCleanUp(newValue)
        }
    }
}

struct DelegatesSettingsView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var showingAddDelegate = false
    @State private var editingDelegate: Delegate?
    @State private var editedShortName = ""
    @State private var editedFullName = ""
    
    var body: some View {
        Form {
            Section(header: Text("Delegates")) {
                if remindersManager.delegates.isEmpty {
                    Text("No delegates found. Add delegates to manage task assignments.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(remindersManager.delegates) { delegate in
                        if editingDelegate?.id == delegate.id {
                            // Edit mode
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Short Name (for hashtag)", text: $editedShortName)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                
                                TextField("Full Name (optional)", text: $editedFullName)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Button("Save") {
                                        Task {
                                            await remindersManager.updateDelegate(delegate, newShortName: editedShortName, newFullName: editedFullName)
                                            editingDelegate = nil
                                            editedShortName = ""
                                            editedFullName = ""
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Cancel") {
                                        editingDelegate = nil
                                        editedShortName = ""
                                        editedFullName = ""
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            // Display mode
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(delegate.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Tag: \(delegate.hashtag)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    editedShortName = delegate.shortName
                                    editedFullName = delegate.fullName
                                    editingDelegate = delegate
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                Button(role: .destructive, action: {
                                    Task {
                                        await remindersManager.removeDelegate(delegate)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Button(action: {
                    showingAddDelegate = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Delegate")
                    }
                }
            }
        }
        .navigationTitle("Delegates")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddDelegate) {
            AddDelegateView(remindersManager: remindersManager)
        }
        .task {
            await remindersManager.loadDelegates()
        }
    }
}

struct AddDelegateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var remindersManager: RemindersManager
    @State private var shortName = ""
    @State private var fullName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Delegate")) {
                    TextField("Short Name (for hashtag)", text: $shortName)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Full Name (optional)", text: $fullName)
                        .autocapitalization(.words)
                }
                
                Section(footer: Text("Short name is used for the hashtag (e.g., #JohnD). Full name is displayed in the delegate list.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Delegate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await remindersManager.addDelegate(shortName: shortName, fullName: fullName)
                            dismiss()
                        }
                    }
                    .disabled(shortName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 250)
        #endif
    }
}
