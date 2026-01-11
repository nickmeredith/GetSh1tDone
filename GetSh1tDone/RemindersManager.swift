import Foundation
import EventKit
import Combine

@MainActor
class RemindersManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var tasks: [TaskItem] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var lastError: String?
    
    private var notificationObserver: NSObjectProtocol?
    
    init() {
        checkAuthorizationStatus()
        setupEventStoreNotifications()
    }
    
    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    private func setupEventStoreNotifications() {
        // Listen for changes to the EventKit store (when reminders are updated externally)
        notificationObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                await self?.loadReminders()
            }
        }
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    func requestAccess() async throws {
        if #available(iOS 17.0, macOS 14.0, *) {
            // Use new iOS 17+ / macOS 14+ API
            _ = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                checkAuthorizationStatus()
            }
        } else {
            // Fallback for older versions
            _ = try await eventStore.requestAccess(to: .reminder)
            await MainActor.run {
                checkAuthorizationStatus()
            }
        }
    }
    
    func loadReminders() async {
        // Check for authorized status (works for both old and new API)
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            // iOS 17+ / macOS 14+ uses .fullAccess instead of .authorized
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        print("🔐 Authorization status: \(currentStatus.rawValue), Authorized: \(isAuthorized)")
        
        guard isAuthorized else {
            print("❌ Not authorized to load reminders. Status: \(currentStatus.rawValue)")
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Get all reminder calendars to ensure we're loading from all sources
        let calendars = eventStore.calendars(for: .reminder)
        print("📅 Found \(calendars.count) reminder calendars")
        for calendar in calendars {
            print("   - \(calendar.title) (Source: \(calendar.source.title))")
        }
        
        // Use nil to get reminders from all calendars
        let predicate = eventStore.predicateForReminders(in: nil)
        
        // Use withCheckedContinuation to wrap the completion handler API
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let reminderList = reminders ?? []
                print("📥 Fetched \(reminderList.count) reminders from EventKit")
                continuation.resume(returning: reminderList)
            }
        }
        
        var loadedTasks: [TaskItem] = []
        
        print("📋 Loading \(reminders.count) reminders...")
        
        // Filter out completed reminders
        let incompleteReminders = reminders.filter { !$0.isCompleted }
        print("📋 Found \(incompleteReminders.count) incomplete reminders (filtered out \(reminders.count - incompleteReminders.count) completed)")
        
        var quadrantCounts: [Quadrant: Int] = [.doNow: 0, .delegate: 0, .schedule: 0, .bin: 0]
        var sampleReminders: [String] = []
        
        for (index, reminder) in incompleteReminders.enumerated() {
            // Only process non-completed reminders
            // Determine quadrant from tags (priority: DoNow > Delegate > Schedule > Bin)
            // Only include tasks that have an explicit quadrant tag
            guard let quadrant = extractQuadrant(from: reminder) else {
                // Skip reminders without a quadrant tag
                continue
            }
            
            let task = TaskItem(reminder: reminder, quadrant: quadrant)
            
            quadrantCounts[quadrant, default: 0] += 1
            
            // Collect sample reminders for debugging (first 10)
            if index < 10 {
                let notes = reminder.notes ?? ""
                let notesPreview = notes.isEmpty ? "(empty)" : String(notes.prefix(100))
                sampleReminders.append("'\(reminder.title ?? "")' → \(quadrant.rawValue) | Notes: \(notesPreview)")
            }
            
            // Debug: Show tags found (tags are now extracted in TaskItem.init)
            if !task.tags.isEmpty {
                print("   📌 Other tags found for '\(reminder.title ?? "")': \(task.tags.joined(separator: ", "))")
            }
            
            loadedTasks.append(task)
        }
        
        print("\n📊 SUMMARY:")
        print("✅ Loaded \(loadedTasks.count) tasks")
        print("   - Do Now: \(quadrantCounts[.doNow] ?? 0)")
        print("   - Delegate: \(quadrantCounts[.delegate] ?? 0)")
        print("   - Schedule: \(quadrantCounts[.schedule] ?? 0)")
        print("   - Bin: \(quadrantCounts[.bin] ?? 0)")
        print("\n📝 Sample reminders (first 10):")
        for sample in sampleReminders {
            print("   \(sample)")
        }
        
        tasks = loadedTasks
    }
    
    private func extractQuadrant(from reminder: EKReminder) -> Quadrant? {
        let title = reminder.title ?? ""
        let notes = reminder.notes ?? ""
        let calendarName = reminder.calendar?.title ?? ""
        
        // Combine notes, title, and calendar name for searching (hashtags can appear in any)
        let combinedText = "\(notes) \(title) \(calendarName)"
        let lowercased = combinedText.lowercased()
        
        // Check for each quadrant hashtag using flexible patterns
        // Priority order: DoNow > Delegate > Schedule > Bin
        // If multiple quadrant tags exist, uses priority order (first match wins)
        let quadrantChecks: [(String, Quadrant)] = [
            ("donow", .doNow),        // Highest priority
            ("delegate", .delegate),
            ("schedule", .schedule),
            ("bin", .bin)             // Lowest priority
        ]
        
        // First, try simple contains check (most permissive)
        // This catches: #DoNow, #donow, ##DoNow, # #DoNow, etc.
        for (tagText, quadrant) in quadrantChecks {
            // Check for the tag text after a # (with or without spaces/hashes)
            // This is very permissive and will match:
            // - #donow, #DoNow, #DONOW
            // - ##donow, ###donow
            // - # #donow, #  #donow
            // - # donow, #  donow
            // - Anywhere in the text
            
            // Simple check: look for # followed by the tag text (case-insensitive)
            // We'll check multiple variations
            let searchPatterns = [
                "#\(tagText)",           // #donow
                "##\(tagText)",          // ##donow
                "# \(tagText)",          // # donow
                "# #\(tagText)",         // # #donow
                "## \(tagText)",         // ## donow
                "#  \(tagText)",         // #  donow
                "#  #\(tagText)",        // #  #donow
                "#\(tagText.capitalized)", // #Donow
                "#\(tagText.uppercased())" // #DONOW
            ]
            
            for pattern in searchPatterns {
                if lowercased.contains(pattern.lowercased()) {
                    print("✅ Found \(tagText) hashtag in reminder: '\(title)'")
                    print("   Matched: '\(pattern)'")
                    print("   Notes: '\(notes.prefix(100))'")
                    print("   Calendar: '\(calendarName)'")
                    print("   → Assigned to quadrant: \(quadrant.rawValue)")
                    return quadrant
                }
            }
            
            // Also try regex for more complex patterns
            // Pattern: one or more #, optional spaces, then tag text
            let regexPattern = "#+\\s*" + tagText
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {
                    print("✅ Found \(tagText) hashtag (regex) in reminder: '\(title)'")
                    print("   Notes: '\(notes.prefix(100))'")
                    print("   Calendar: '\(calendarName)'")
                    print("   → Assigned to quadrant: \(quadrant.rawValue)")
                    return quadrant
                }
            }
        }
        
        // Debug: Print reminder details if no hashtag found (only for first few to avoid spam)
        // But always log if notes are not empty (might have tags we're missing)
        if notes.isEmpty {
            // Only log occasionally for empty notes to avoid spam
            if tasks.count < 5 || tasks.count % 50 == 0 {
                print("⚠️ No quadrant hashtag found in reminder: '\(title)' - skipping")
                print("   Notes: (empty)")
                print("   Calendar: '\(calendarName)'")
            }
        } else {
            // Always log if notes exist but no tag found - might indicate a parsing issue
            print("⚠️ No quadrant hashtag found in reminder: '\(title)' - skipping")
            print("   Notes: '\(notes.prefix(200))'")
            print("   Calendar: '\(calendarName)'")
            print("   Lowercased combined: '\(lowercased.prefix(300))'")
        }
        
        // Return nil if no hashtag found - task will be excluded
        return nil
    }
    
    func moveTask(_ task: TaskItem, to quadrant: Quadrant) async {
        guard let reminder = task.reminder else { return }
        
        // Ensure reminder is in iCloud calendar if possible
        if let iCloudCalendar = getiCloudRemindersCalendar(), reminder.calendar != iCloudCalendar {
            reminder.calendar = iCloudCalendar
            print("📅 Moving reminder to iCloud calendar: \(iCloudCalendar.title)")
        }
        
        // Preserve existing notes and tags, just update quadrant hashtag
        var notes = reminder.notes ?? ""
        
        // Remove old quadrant hashtags from notes
        let oldQuadrantTags = Quadrant.allCases.map { $0.hashtag.lowercased() }
        let lines = notes.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        
        for line in lines {
            var cleanedLine = line
            // Remove quadrant hashtags from this line (case-insensitive)
            for oldTag in oldQuadrantTags {
                let patterns = [
                    "#+\\s*" + oldTag.replacingOccurrences(of: "#", with: "") + "\\b",
                    "#\\s+#+\\s*" + oldTag.replacingOccurrences(of: "#", with: "") + "\\b"
                ]
                for pattern in patterns {
                    if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                        let range = NSRange(cleanedLine.startIndex..., in: cleanedLine)
                        cleanedLine = regex.stringByReplacingMatches(in: cleanedLine, options: [], range: range, withTemplate: "")
                    }
                }
            }
            // Also remove simple variations
            for oldTag in ["#DoNow", "#Delegate", "#Schedule", "#Bin", "##DoNow", "##Delegate", "##Schedule", "##Bin", "# #DoNow", "# #Delegate", "# #Schedule", "# #Bin"] {
                cleanedLine = cleanedLine.replacingOccurrences(of: oldTag, with: "", options: .caseInsensitive)
            }
            cleanedLine = cleanedLine.trimmingCharacters(in: .whitespaces)
            if !cleanedLine.isEmpty {
                cleanedLines.append(cleanedLine)
            }
        }
        
        // Rebuild notes: cleaned notes + quadrant hashtag + other tags
        var finalNotes = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if !finalNotes.isEmpty {
            finalNotes += "\n\n"
        }
        finalNotes += quadrant.hashtag
        if !task.tags.isEmpty {
            finalNotes += "\n" + task.tags.joined(separator: " ")
        }
        
        reminder.notes = finalNotes
        
        do {
            try eventStore.save(reminder, commit: true)
            print("✅ Moved task '\(task.title)' to \(quadrant.rawValue) in calendar: \(reminder.calendar.title)")
            // Reload to ensure sync
            await loadReminders()
        } catch {
            let errorMsg = "Error moving reminder: \(error.localizedDescription)"
            print(errorMsg)
            lastError = errorMsg
        }
    }
    
    
    func markTaskCompleted(_ task: TaskItem) async {
        if let reminder = task.reminder {
            reminder.isCompleted = !reminder.isCompleted
            
            do {
                try eventStore.save(reminder, commit: true)
                print("✅ Marked task '\(task.title)' as \(reminder.isCompleted ? "completed" : "incomplete")")
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error marking reminder as completed: \(error.localizedDescription)"
                print(errorMsg)
                lastError = errorMsg
            }
        } else {
            // Update local task if it's not a reminder
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                tasks[index].isCompleted.toggle()
            }
        }
    }
    
    func updateTask(_ task: TaskItem, title: String?, notes: String?, tags: [String]? = nil, dueDate: Date? = nil) async {
        if let reminder = task.reminder {
            // Ensure reminder is in iCloud calendar if possible
            if let iCloudCalendar = getiCloudRemindersCalendar(), reminder.calendar != iCloudCalendar {
                reminder.calendar = iCloudCalendar
                print("📅 Moving reminder to iCloud calendar: \(iCloudCalendar.title)")
            }
            
            // Update title if provided
            if let title = title, !title.isEmpty {
                reminder.title = title
            }
            
            // Update due date - if provided, set it; if explicitly nil (from TaskDetailView), clear it
            // We check if tags was provided to know this is from TaskDetailView (which always provides dueDate)
            if tags != nil {
                // This is from TaskDetailView - always update due date
                if let dueDate = dueDate {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                    reminder.dueDateComponents = components
                    print("📅 Updated due date: \(dueDate)")
                } else {
                    // Clear the due date
                    reminder.dueDateComponents = nil
                    print("📅 Cleared due date")
                }
            } else if let dueDate = dueDate {
                // This is from another view - only set if provided
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                reminder.dueDateComponents = components
                print("📅 Updated due date: \(dueDate)")
            }
            
            // Update notes, preserving quadrant hashtag and tags
            if let notes = notes {
                let currentHashtag = task.quadrant.hashtag
                
                // Build updated notes: user notes + quadrant hashtag + tags
                var updatedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Ensure quadrant hashtag is present
                if !updatedNotes.contains(currentHashtag) {
                    if !updatedNotes.isEmpty {
                        updatedNotes += "\n\n"
                    }
                    updatedNotes += currentHashtag
                }
                
                // Add tags if provided, otherwise use existing tags
                let tagsToAdd = tags ?? task.tags
                if !tagsToAdd.isEmpty {
                    updatedNotes += "\n" + tagsToAdd.joined(separator: " ")
                }
                
                reminder.notes = updatedNotes
            }
            
            do {
                try eventStore.save(reminder, commit: true)
                print("✅ Updated task '\(title ?? task.title)' in calendar: \(reminder.calendar.title)")
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error updating reminder: \(error.localizedDescription)"
                print(errorMsg)
                lastError = errorMsg
            }
        } else {
            // Update local task
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                if let title = title {
                    tasks[index].title = title
                }
                if let notes = notes {
                    tasks[index].notes = notes
                }
                tasks[index].tags = task.tags
                tasks[index].lastModified = Date()
            }
        }
    }
    
    func getTasksForQuadrant(_ quadrant: Quadrant, showCompleted: Bool = true) -> [TaskItem] {
        if showCompleted {
            // Show all tasks in quadrant, including completed ones
            return tasks.filter { $0.quadrant == quadrant }
        } else {
            // Hide completed tasks
            return tasks.filter { $0.quadrant == quadrant && !$0.isCompleted }
        }
    }
    
    func getOldTasks(daysOld: Int = 14) -> [TaskItem] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date()) ?? Date()
        return tasks.filter { $0.lastModified < cutoffDate && !$0.isCompleted }
    }
    
    /// Finds the iCloud Reminders calendar
    private func getiCloudRemindersCalendar() -> EKCalendar? {
        // Get all reminder calendars
        let calendars = eventStore.calendars(for: .reminder)
        
        // Debug: Print all available calendars
        print("📋 Available Reminder Calendars:")
        for calendar in calendars {
            print("  - \(calendar.title) (Source: \(calendar.source.title), Type: \(calendar.source.sourceType.rawValue))")
        }
        
        // Look for iCloud calendar first (CalDAV source with iCloud in name)
        for calendar in calendars {
            if calendar.source.sourceType == .calDAV {
                let sourceTitle = calendar.source.title.lowercased()
                // iCloud calendars can have various names like "iCloud", "iCloud Account", etc.
                if sourceTitle.contains("icloud") {
                    print("✅ Found iCloud calendar: \(calendar.title) from source: \(calendar.source.title)")
                    return calendar
                }
            }
        }
        
        // Also check for local calendars that might be syncing to iCloud
        // On iOS, the default might already be iCloud if that's what's configured
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            let sourceTitle = defaultCalendar.source.title.lowercased()
            if sourceTitle.contains("icloud") || defaultCalendar.source.sourceType == .calDAV {
                print("✅ Default calendar is iCloud: \(defaultCalendar.title)")
                return defaultCalendar
            }
        }
        
        print("⚠️ No iCloud calendar found. Available calendars:")
        for calendar in calendars {
            print("  - \(calendar.title) (Source: \(calendar.source.title))")
        }
        return nil
    }
    
    func addTask(_ task: TaskItem) async {
        // Check authorization first
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        guard isAuthorized else {
            let errorMsg = "Not authorized to create reminders. Please grant access in Settings."
            print(errorMsg)
            lastError = errorMsg
            // Try requesting access again
            do {
                try await requestAccess()
                // Retry after getting access
                let newStatus = EKEventStore.authorizationStatus(for: .reminder)
                let hasAccess: Bool
                if #available(iOS 17.0, macOS 14.0, *) {
                    hasAccess = newStatus == .fullAccess
                } else {
                    hasAccess = newStatus == .authorized
                }
                if hasAccess {
                    await addTask(task)
                }
            } catch {
                lastError = "Failed to request access: \(error.localizedDescription)"
            }
            return
        }
        
        // Get the iCloud calendar for reminders, fallback to default
        var calendar = getiCloudRemindersCalendar()
        if calendar == nil {
            calendar = eventStore.defaultCalendarForNewReminders()
        }
        
        guard let calendar = calendar else {
            let errorMsg = "No calendar available. Please check your Reminders app settings and ensure iCloud is enabled."
            print(errorMsg)
            lastError = errorMsg
            return
        }
        
        print("📅 Using calendar: \(calendar.title) (Source: \(calendar.source.title))")
        
        // Create a new reminder in EventKit
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = task.title
        
        // Build notes with quadrant hashtag and tags
        var notes = task.notes
        if !notes.isEmpty {
            notes += "\n\n"
        }
        notes += task.quadrant.hashtag
        if !task.tags.isEmpty {
            notes += "\n" + task.tags.joined(separator: " ")
        }
        reminder.notes = notes
        reminder.calendar = calendar
        
        do {
            try eventStore.save(reminder, commit: true)
            print("✅ Successfully created reminder: \(task.title)")
            lastError = nil
            await loadReminders()
        } catch {
            let errorMsg = "Error creating reminder: \(error.localizedDescription)"
            print(errorMsg)
            print("Full error: \(error)")
            lastError = errorMsg
        }
    }
    
    func deleteTask(_ task: TaskItem) async {
        if let reminder = task.reminder {
            do {
                try eventStore.remove(reminder, commit: true)
                print("✅ Deleted task '\(task.title)'")
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error deleting reminder: \(error.localizedDescription)"
                print(errorMsg)
                lastError = errorMsg
            }
        } else {
            // Remove from local tasks if it's not a reminder
            tasks.removeAll { $0.id == task.id }
        }
    }
}

