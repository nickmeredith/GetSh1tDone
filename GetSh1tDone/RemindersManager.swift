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
    @Published var delegates: [String] = []
    
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
        
        // Filter reminders: include incomplete ones and completed ones from today
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let filteredReminders = reminders.filter { reminder in
            if !reminder.isCompleted {
                // Include all incomplete reminders
                return true
            } else {
                // Include completed reminders that were completed today
                if let completionDate = reminder.completionDate {
                    let completionDay = calendar.startOfDay(for: completionDate)
                    return completionDay >= today && completionDay < tomorrow
                }
                return false
            }
        }
        
        let completedTodayCount = reminders.filter { $0.isCompleted && 
            ($0.completionDate.map { calendar.startOfDay(for: $0) >= today && calendar.startOfDay(for: $0) < tomorrow } ?? false)
        }.count
        
        print("📋 Found \(filteredReminders.count) reminders to load:")
        print("   - Incomplete: \(filteredReminders.filter { !$0.isCompleted }.count)")
        print("   - Completed today: \(completedTodayCount)")
        print("   - Filtered out: \(reminders.count - filteredReminders.count) (completed on other days)")
        
        var quadrantCounts: [Quadrant: Int] = [.doNow: 0, .delegate: 0, .schedule: 0, .bin: 0]
        var sampleReminders: [String] = []

        for (index, reminder) in filteredReminders.enumerated() {
            // Determine quadrant from tags (priority: DoNow > Delegate > Schedule > Bin)
            var quadrant: Quadrant?
            
            // First, try to extract quadrant from tags
            quadrant = extractQuadrant(from: reminder)
            
            // If no quadrant tag found, check if it has a time period tag
            // If it does, assign it to Schedule as default so it shows up in Plan view
            if quadrant == nil {
                let notes = reminder.notes ?? ""
                let title = reminder.title ?? ""
                let calendarName = reminder.calendar?.title ?? ""
                let combinedText = "\(notes) \(title) \(calendarName)"
                let lowercased = combinedText.lowercased()
                
                // Check for time period tags with variations (similar to quadrant tag detection)
                let timePeriodTags = [
                    ("today", "#today"),
                    ("thisweek", "#thisweek"),
                    ("thismonth", "#thismonth"),
                    ("thisquarter", "#thisquarter")
                ]
                
                var hasTimePeriodTag = false
                for (tagText, tag) in timePeriodTags {
                    // Check multiple variations: #today, ##today, # today, etc.
                    let searchPatterns = [
                        "#\(tagText)",           // #today
                        "##\(tagText)",          // ##today
                        "# \(tagText)",          // # today
                        "# #\(tagText)",         // # #today
                        "## \(tagText)",         // ## today
                        "#  \(tagText)",         // #  today
                        "#  #\(tagText)"         // #  #today
                    ]
                    
                    for pattern in searchPatterns {
                        if lowercased.contains(pattern.lowercased()) {
                            hasTimePeriodTag = true
                            break
                        }
                    }
                    if hasTimePeriodTag { break }
                }
                
                if hasTimePeriodTag {
                    // Assign to Schedule as default quadrant for tasks with time period tags
                    quadrant = .schedule
                    print("📅 Task '\(reminder.title ?? "")' has time period tag but no quadrant tag - assigning to Schedule")
                }
            }
            
            // Skip if still no quadrant (no quadrant tag and no time period tag)
            guard let quadrant = quadrant else {
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
                // Step 1: Deduplicate tags (case-insensitive)
                let tagsToAdd = tags ?? task.tags
                var seenTags = Set<String>()
                let uniqueTags = tagsToAdd.compactMap { tag -> String? in
                    let lower = tag.lowercased()
                    if seenTags.contains(lower) {
                        return nil
                    }
                    seenTags.insert(lower)
                    return tag
                }
                
                // Step 2: Extract tags from notes and combine, ensuring no duplicates
                let existingTagsInNotes = TaskItem.extractTags(from: updatedNotes)
                var seenTagsInNotes = Set<String>()
                let uniqueTagsInNotes = existingTagsInNotes.compactMap { tag -> String? in
                    let lower = tag.lowercased()
                    if seenTagsInNotes.contains(lower) {
                        return nil
                    }
                    seenTagsInNotes.insert(lower)
                    return tag
                }
                
                // Step 3: Combine all tags, ensuring no duplicates
                var allTags = uniqueTags
                for existingTag in uniqueTagsInNotes {
                    if !allTags.contains(where: { $0.lowercased() == existingTag.lowercased() }) {
                        allTags.append(existingTag)
                    }
                }
                
                // Step 4: Final deduplication pass
                var finalSeenTags = Set<String>()
                let finalUniqueTags = allTags.compactMap { tag -> String? in
                    let lower = tag.lowercased()
                    if finalSeenTags.contains(lower) {
                        return nil
                    }
                    finalSeenTags.insert(lower)
                    return tag
                }
                
                // Step 5: Remove existing tags from notes before adding deduplicated ones
                // Remove all hashtags except quadrant hashtag
                let lines = updatedNotes.components(separatedBy: .newlines)
                var cleanedLines: [String] = []
                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    // Keep lines that don't start with # (except quadrant hashtag which we'll add separately)
                    if !trimmedLine.hasPrefix("#") || trimmedLine == currentHashtag {
                        cleanedLines.append(line)
                    }
                }
                updatedNotes = cleanedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Ensure quadrant hashtag is present
                if !updatedNotes.contains(currentHashtag) {
                    if !updatedNotes.isEmpty {
                        updatedNotes += "\n\n"
                    }
                    updatedNotes += currentHashtag
                }
                
                if !finalUniqueTags.isEmpty {
                    updatedNotes += "\n" + finalUniqueTags.joined(separator: " ")
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
    
    func getTasksForQuadrant(_ quadrant: Quadrant, showCompleted: Bool = true, showOnlyToday: Bool = false, showOnlyThisWeek: Bool = false) -> [TaskItem] {
        var filteredTasks = tasks.filter { $0.quadrant == quadrant }
        
        // Filter by completion status
        if !showCompleted {
            filteredTasks = filteredTasks.filter { !$0.isCompleted }
        }
        
        // Filter by time period tags
        if showOnlyToday {
            filteredTasks = filteredTasks.filter { task in
                hasTimePeriodTag(task, tag: "#today")
            }
        } else if showOnlyThisWeek {
            filteredTasks = filteredTasks.filter { task in
                hasTimePeriodTag(task, tag: "#thisweek")
            }
        }
        
        return filteredTasks
    }
    
    func hasTimePeriodTag(_ task: TaskItem, tag: String) -> Bool {
        let allTags = task.tags + TaskItem.extractTags(from: task.notes)
        let lowerTag = tag.lowercased()
        return allTags.contains { $0.lowercased() == lowerTag }
    }
    
    func toggleTimePeriodTag(_ task: TaskItem, tag: String) async {
        // Check if tag already exists
        let hasTag = hasTimePeriodTag(task, tag: tag)
        
        if hasTag {
            // Remove the tag
            await removeTimePeriodTag(task, tag: tag)
        } else {
            // Add the tag
            await setTimePeriodTag(task, tag: tag)
        }
    }
    
    func removeTimePeriodTag(_ task: TaskItem, tag: String) async {
        if let reminder = task.reminder {
            let timePeriodTags = ["#today", "#thisweek", "#thismonth", "#thisquarter"]
            
            // Get current notes and tags
            let currentNotes = reminder.notes ?? ""
            let currentHashtag = task.quadrant.hashtag
            
            // Extract existing tags, excluding the specific time period tag to remove
            var existingTags = TaskItem.extractTags(from: currentNotes)
            let lowerTagToRemove = tag.lowercased()
            existingTags = existingTags.filter { existingTag in
                existingTag.lowercased() != lowerTagToRemove
            }
            
            // Rebuild notes: user notes + quadrant hashtag + remaining tags
            var userNotes = currentNotes
                .replacingOccurrences(of: currentHashtag, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove the specific time period tag from user notes
            userNotes = userNotes.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
            userNotes = userNotes.replacingOccurrences(of: tag.capitalized, with: "", options: .caseInsensitive)
            userNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var updatedNotes = userNotes
            if !updatedNotes.isEmpty {
                updatedNotes += "\n\n"
            }
            updatedNotes += currentHashtag
            if !existingTags.isEmpty {
                updatedNotes += "\n" + existingTags.joined(separator: " ")
            }
            
            reminder.notes = updatedNotes
            
            do {
                try eventStore.save(reminder, commit: true)
                print("✅ Removed time period tag '\(tag)' from task '\(task.title)'")
                await loadReminders()
            } catch {
                let errorMsg = "Error removing time period tag: \(error.localizedDescription)"
                print(errorMsg)
                lastError = errorMsg
            }
        }
    }
    
    func setTimePeriodTag(_ task: TaskItem, tag: String) async {
        if let reminder = task.reminder {
            let timePeriodTags = ["#today", "#thisweek", "#thismonth", "#thisquarter"]
            
            // Get current notes and tags
            let currentNotes = reminder.notes ?? ""
            let currentHashtag = task.quadrant.hashtag
            
            // Extract existing tags, excluding time period tags
            var existingTags = TaskItem.extractTags(from: currentNotes)
            existingTags = existingTags.filter { tag in
                !timePeriodTags.contains { $0.lowercased() == tag.lowercased() }
            }
            
            // Add the new time period tag (avoid duplicates)
            let lowerNewTag = tag.lowercased()
            if !existingTags.contains(where: { $0.lowercased() == lowerNewTag }) {
                existingTags.append(tag)
            }
            
            // Remove any remaining duplicates (case-insensitive)
            var seenTags = Set<String>()
            existingTags = existingTags.filter { tag in
                let lower = tag.lowercased()
                if seenTags.contains(lower) {
                    return false
                }
                seenTags.insert(lower)
                return true
            }
            
            // Rebuild notes: user notes + quadrant hashtag + tags
            var userNotes = currentNotes
                .replacingOccurrences(of: currentHashtag, with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove all time period tags from user notes
            for timeTag in timePeriodTags {
                userNotes = userNotes.replacingOccurrences(of: timeTag, with: "", options: .caseInsensitive)
                userNotes = userNotes.replacingOccurrences(of: timeTag.capitalized, with: "", options: .caseInsensitive)
            }
            userNotes = userNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var updatedNotes = userNotes
            if !updatedNotes.isEmpty {
                updatedNotes += "\n\n"
            }
            updatedNotes += currentHashtag
            if !existingTags.isEmpty {
                updatedNotes += "\n" + existingTags.joined(separator: " ")
            }
            
            reminder.notes = updatedNotes
            
            do {
                try eventStore.save(reminder, commit: true)
                print("✅ Set time period tag '\(tag)' for task '\(task.title)'")
                await loadReminders()
            } catch {
                let errorMsg = "Error setting time period tag: \(error.localizedDescription)"
                print(errorMsg)
                lastError = errorMsg
            }
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
    
    func addTask(_ task: TaskItem, dueDate: Date? = nil) async {
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
        // Step 1: Deduplicate tags from task.tags (case-insensitive)
        var seenTags = Set<String>()
        let uniqueTagsFromTask = task.tags.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if seenTags.contains(lower) {
                return nil
            }
            seenTags.insert(lower)
            return tag
        }
        
        // Step 2: Start with user's notes (which may already contain tags from AddTaskView)
        var notes = task.notes
        
        // Step 3: Extract existing tags from notes and deduplicate
        let existingTagsInNotes = TaskItem.extractTags(from: notes)
        var seenTagsInNotes = Set<String>()
        let uniqueTagsInNotes = existingTagsInNotes.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if seenTagsInNotes.contains(lower) {
                return nil
            }
            seenTagsInNotes.insert(lower)
            return tag
        }
        
        // Step 4: Combine tags from task.tags and notes, ensuring all tags are present and deduplicated
        var allTags = uniqueTagsFromTask
        for existingTag in uniqueTagsInNotes {
            if !allTags.contains(where: { $0.lowercased() == existingTag.lowercased() }) {
                allTags.append(existingTag)
            }
        }
        
        // Step 5: Final deduplication pass (case-insensitive)
        var finalSeenTags = Set<String>()
        let finalUniqueTags = allTags.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if finalSeenTags.contains(lower) {
                return nil
            }
            finalSeenTags.insert(lower)
            return tag
        }
        
        // Step 6: Build final notes: user notes + quadrant hashtag + all deduplicated tags
        // Remove quadrant hashtag from notes if it's already there
        let quadrantHashtag = task.quadrant.hashtag
        notes = notes.replacingOccurrences(of: quadrantHashtag, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !notes.isEmpty {
            notes += "\n\n"
        }
        notes += quadrantHashtag
        if !finalUniqueTags.isEmpty {
            notes += "\n" + finalUniqueTags.joined(separator: " ")
        }
        reminder.notes = notes
        reminder.calendar = calendar
        
        // Set due date if provided
        if let dueDate = dueDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            print("📅 Set due date: \(dueDate)")
        }
        
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
    
    // MARK: - Delegate Management
    
    func loadDelegates() async {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        guard isAuthorized else {
            print("❌ Not authorized to load delegates")
            return
        }
        
        // Find the "Delegates" list
        let calendars = eventStore.calendars(for: .reminder)
        guard let delegatesCalendar = calendars.first(where: { $0.title.lowercased() == "delegates" }) else {
            print("⚠️ Delegates list not found")
            delegates = []
            return
        }
        
        // Fetch all reminders from the Delegates list
        let predicate = eventStore.predicateForReminders(in: [delegatesCalendar])
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        // Extract delegate names from reminder titles
        let delegateNames = reminders.compactMap { $0.title }.filter { !$0.isEmpty }
        delegates = delegateNames.sorted()
        print("✅ Loaded \(delegates.count) delegates: \(delegates.joined(separator: ", "))")
    }
    
    func addDelegate(_ name: String) async {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        guard isAuthorized else {
            lastError = "Not authorized to add delegates"
            return
        }
        
        // Find or create the "Delegates" list
        let calendars = eventStore.calendars(for: .reminder)
        var delegatesCalendar = calendars.first(where: { $0.title.lowercased() == "delegates" })
        
        if delegatesCalendar == nil {
            // Create the Delegates list
            delegatesCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
            delegatesCalendar?.title = "Delegates"
            
            // Try to use iCloud calendar source
            if let iCloudSource = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
                delegatesCalendar?.source = iCloudSource
            } else if let defaultSource = eventStore.sources.first(where: { $0.sourceType == .local }) {
                delegatesCalendar?.source = defaultSource
            }
            
            do {
                try eventStore.saveCalendar(delegatesCalendar!, commit: true)
                print("✅ Created Delegates list")
            } catch {
                lastError = "Failed to create Delegates list: \(error.localizedDescription)"
                print("❌ \(lastError ?? "")")
                return
            }
        }
        
        guard let calendar = delegatesCalendar else {
            lastError = "Could not access Delegates list"
            return
        }
        
        // Check if delegate already exists
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let existingReminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        if existingReminders.contains(where: { $0.title?.lowercased() == name.lowercased() }) {
            print("⚠️ Delegate '\(name)' already exists")
            await loadDelegates()
            return
        }
        
        // Create a new reminder for the delegate
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = name.trimmingCharacters(in: .whitespaces)
        reminder.calendar = calendar
        
        do {
            try eventStore.save(reminder, commit: true)
            print("✅ Added delegate: \(name)")
            await loadDelegates()
        } catch {
            lastError = "Failed to add delegate: \(error.localizedDescription)"
            print("❌ \(lastError ?? "")")
        }
    }
    
    func removeDelegate(_ name: String) async {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        guard isAuthorized else {
            lastError = "Not authorized to remove delegates"
            return
        }
        
        // Find the "Delegates" list
        let calendars = eventStore.calendars(for: .reminder)
        guard let delegatesCalendar = calendars.first(where: { $0.title.lowercased() == "delegates" }) else {
            lastError = "Delegates list not found"
            return
        }
        
        // Find the reminder with this name
        let predicate = eventStore.predicateForReminders(in: [delegatesCalendar])
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        guard let reminder = reminders.first(where: { $0.title?.lowercased() == name.lowercased() }) else {
            lastError = "Delegate not found"
            return
        }
        
        do {
            try eventStore.remove(reminder, commit: true)
            print("✅ Removed delegate: \(name)")
            await loadDelegates()
        } catch {
            lastError = "Failed to remove delegate: \(error.localizedDescription)"
            print("❌ \(lastError ?? "")")
        }
    }
    
    func updateDelegate(oldName: String, newName: String) async {
        guard !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        
        guard isAuthorized else {
            lastError = "Not authorized to update delegates"
            return
        }
        
        // Find the "Delegates" list
        let calendars = eventStore.calendars(for: .reminder)
        guard let delegatesCalendar = calendars.first(where: { $0.title.lowercased() == "delegates" }) else {
            lastError = "Delegates list not found"
            return
        }
        
        // Find the reminder with the old name
        let predicate = eventStore.predicateForReminders(in: [delegatesCalendar])
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        guard let reminder = reminders.first(where: { $0.title?.lowercased() == oldName.lowercased() }) else {
            lastError = "Delegate not found"
            return
        }
        
        reminder.title = newName.trimmingCharacters(in: .whitespaces)
        
        do {
            try eventStore.save(reminder, commit: true)
            print("✅ Updated delegate: \(oldName) → \(newName)")
            await loadDelegates()
        } catch {
            lastError = "Failed to update delegate: \(error.localizedDescription)"
            print("❌ \(lastError ?? "")")
        }
    }
}

