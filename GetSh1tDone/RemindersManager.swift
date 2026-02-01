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
    @Published var delegates: [Delegate] = []
    
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
        
        #if DEBUG
        print("🔐 Authorization status: \(currentStatus.rawValue), Authorized: \(isAuthorized)")
        #endif
        
        guard isAuthorized else {
            #if DEBUG
            print("❌ Not authorized to load reminders. Status: \(currentStatus.rawValue)")
            #endif
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Get all reminder calendars to ensure we're loading from all sources
        let calendars = eventStore.calendars(for: .reminder)
        #if DEBUG
        print("📅 Found \(calendars.count) reminder calendars")
        #endif
        for calendar in calendars {
            #if DEBUG
            print("   - \(calendar.title) (Source: \(calendar.source.title))")
            #endif
        }
        
        // Use nil to get reminders from all calendars
        let predicate = eventStore.predicateForReminders(in: nil)
        
        // Use withCheckedContinuation to wrap the completion handler API
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                let reminderList = reminders ?? []
                #if DEBUG
                print("📥 Fetched \(reminderList.count) reminders from EventKit")
                #endif
                continuation.resume(returning: reminderList)
            }
        }
        
        var loadedTasks: [TaskItem] = []
        
        #if DEBUG
        print("📋 Loading \(reminders.count) reminders...")
        #endif
        
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
        
        #if DEBUG
        print("📋 Found \(filteredReminders.count) reminders to load:")
        #endif
        #if DEBUG
        print("   - Incomplete: \(filteredReminders.filter { !$0.isCompleted }.count)")
        #endif
        #if DEBUG
        print("   - Completed today: \(completedTodayCount)")
        #endif
        #if DEBUG
        print("   - Filtered out: \(reminders.count - filteredReminders.count) (completed on other days)")
        #endif
        
        var quadrantCounts: [Quadrant: Int] = [.doNow: 0, .delegate: 0, .schedule: 0, .bin: 0]
        var sampleReminders: [String] = []

        for (index, reminder) in filteredReminders.enumerated() {
            // Determine quadrant from tags (priority: DoNow > Delegate > Schedule > Bin)
            var quadrant: Quadrant?
            
            // First, try to extract quadrant from tags
            quadrant = extractQuadrant(from: reminder)
            
            // If no quadrant tag found, check if it has a time period tag or challenge tag
            // If it has a time period tag, assign it to Schedule as default so it shows up in Plan view
            // If it has a challenge tag, assign it to Bin / Challenge quadrant
            if quadrant == nil {
                let notes = reminder.notes ?? ""
                let title = reminder.title ?? ""
                let calendarName = reminder.calendar?.title ?? ""
                let combinedText = "\(notes) \(title) \(calendarName)"
                let lowercased = combinedText.lowercased()
                
                // First check for challenge tag
                let challengePatterns = [
                    "#challenge",
                    "##challenge",
                    "# challenge",
                    "# #challenge",
                    "## challenge"
                ]
                
                var hasChallengeTag = false
                for pattern in challengePatterns {
                    if lowercased.contains(pattern.lowercased()) {
                        hasChallengeTag = true
                        break
                    }
                }
                
                if hasChallengeTag {
                    // Assign to Bin / Challenge quadrant for tasks with challenge tag
                    quadrant = .bin
                    #if DEBUG
                    print("🎯 Task '\(reminder.title ?? "")' has #challenge tag - assigning to Bin / Challenge")
                    #endif
                } else {
                    // Check for time period tags with variations (similar to quadrant tag detection)
                    let timePeriodTagTexts = ["today", "thisweek", "thismonth", "thisquarter"]
                    
                    var hasTimePeriodTag = false
                    for tagText in timePeriodTagTexts {
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
                        #if DEBUG
                        print("📅 Task '\(reminder.title ?? "")' has time period tag but no quadrant tag - assigning to Schedule")
                        #endif
                    }
                }
            }
            
            // Skip if still no quadrant (no quadrant tag, no challenge tag, and no time period tag)
            guard let quadrant = quadrant else {
                continue
            }
            
            var task = TaskItem(reminder: reminder, quadrant: quadrant)
            
            // Normalize tags: ensure tags are in both notes and tags field, remove duplicates
            task = normalizeTaskTagsAndNotes(task)
            
            // Update the reminder in EventKit if normalization changed anything
            if let reminder = task.reminder {
                let currentNotes = reminder.notes ?? ""
                if currentNotes != task.notes {
                    reminder.notes = task.notes
                    do {
                        try eventStore.save(reminder, commit: false)
                        #if DEBUG
                        print("🔄 Updated reminder notes for '\(task.title)' to sync tags")
                        #endif
                    } catch {
                        #if DEBUG
                        print("⚠️ Failed to update reminder notes: \(error.localizedDescription)")
                        #endif
                    }
                }
            }
            
            quadrantCounts[quadrant, default: 0] += 1
            
            // Collect sample reminders for debugging (first 10)
            if index < 10 {
                let notes = reminder.notes ?? ""
                let notesPreview = notes.isEmpty ? "(empty)" : String(notes.prefix(100))
                sampleReminders.append("'\(reminder.title ?? "")' → \(quadrant.rawValue) | Notes: \(notesPreview)")
            }
            
            // Debug: Show tags found (tags are now extracted in TaskItem.init)
            if !task.tags.isEmpty {
                #if DEBUG
                print("   📌 Other tags found for '\(reminder.title ?? "")': \(task.tags.joined(separator: ", "))")
                #endif
            }
            
            loadedTasks.append(task)
        }
        
        #if DEBUG
        print("\n📊 SUMMARY:")
        #endif
        #if DEBUG
        print("✅ Loaded \(loadedTasks.count) tasks")
        #endif
        #if DEBUG
        print("   - Do Now: \(quadrantCounts[.doNow] ?? 0)")
        #endif
        #if DEBUG
        print("   - Delegate: \(quadrantCounts[.delegate] ?? 0)")
        #endif
        #if DEBUG
        print("   - Schedule: \(quadrantCounts[.schedule] ?? 0)")
        #endif
        #if DEBUG
        print("   - Bin: \(quadrantCounts[.bin] ?? 0)")
        #endif
        #if DEBUG
        print("\n📝 Sample reminders (first 10):")
        #endif
        for sample in sampleReminders {
            #if DEBUG
            print("   \(sample)")
            #endif
        }
        
        // Commit all reminder updates at once
        do {
            try eventStore.commit()
            #if DEBUG
            print("✅ Committed all reminder updates")
            #endif
        } catch {
            #if DEBUG
            print("⚠️ Failed to commit reminder updates: \(error.localizedDescription)")
            #endif
        }
        
        tasks = loadedTasks
    }
    
    /// Normalizes task tags and notes to ensure:
    /// 1. All tags from notes are in tags array
    /// 2. All tags from tags array are in notes
    /// 3. No duplicate hashtags in notes
    /// 4. No duplicate hashtags in tags array
    private func normalizeTaskTagsAndNotes(_ task: TaskItem) -> TaskItem {
        var normalizedTask = task
        
        // Step 1: Extract all unique tags from notes (case-insensitive deduplication)
        let tagsFromNotes = TaskItem.extractTags(from: task.notes)
        var seenTagsFromNotes = Set<String>()
        let uniqueTagsFromNotes = tagsFromNotes.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if seenTagsFromNotes.contains(lower) {
                return nil
            }
            seenTagsFromNotes.insert(lower)
            return tag
        }
        
        // Step 2: Combine tags from both sources (notes and tags array)
        var allUniqueTags = uniqueTagsFromNotes
        var seenAllTags = Set<String>()
        for tag in uniqueTagsFromNotes {
            seenAllTags.insert(tag.lowercased())
        }
        
        // Add tags from tags array that aren't already in notes
        for tag in task.tags {
            let lower = tag.lowercased()
            if !seenAllTags.contains(lower) {
                allUniqueTags.append(tag)
                seenAllTags.insert(lower)
            }
        }
        
        // Step 3: Final deduplication pass (case-insensitive)
        var finalSeenTags = Set<String>()
        let finalUniqueTags = allUniqueTags.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if finalSeenTags.contains(lower) {
                return nil
            }
            finalSeenTags.insert(lower)
            return tag
        }
        
        // Step 4: Extract non-hashtag content from notes (user's actual notes)
        // Remove all hashtags to get just the user content
        var userNotes = task.notes
        
        // Remove all hashtag patterns (handles #tag, ##tag, # tag, etc.)
        let hashtagPattern = #"#+\s*#?\w+"#
        if let regex = try? NSRegularExpression(pattern: hashtagPattern, options: []) {
            let range = NSRange(userNotes.startIndex..., in: userNotes)
            userNotes = regex.stringByReplacingMatches(
                in: userNotes,
                options: [],
                range: range,
                withTemplate: ""
            )
        }
        
        // Clean up: remove extra whitespace and newlines
        userNotes = userNotes
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Step 5: Rebuild notes with user content + quadrant hashtag + all unique tags
        // Format tags in a way that Apple Reminders might recognize
        let quadrantHashtag = task.quadrant.hashtag
        var rebuiltNotes = userNotes
        
        // Always add quadrant hashtag
        if !rebuiltNotes.isEmpty {
            rebuiltNotes += "\n\n"
        }
        rebuiltNotes += quadrantHashtag
        
        // Always add tags if we have any
        // Format: Put tags on separate lines to help Apple Reminders recognize them
        if !finalUniqueTags.isEmpty {
            rebuiltNotes += "\n"
            // Add each tag on its own line - some versions of Reminders recognize this better
            for (index, tag) in finalUniqueTags.enumerated() {
                if index > 0 {
                    rebuiltNotes += " "
                }
                rebuiltNotes += tag
            }
        }
        
        // Debug logging for normalization
        #if DEBUG
        print("🔧 Normalization details:")
        #endif
        #if DEBUG
        print("   - Original notes: '\(task.notes)'")
        #endif
        #if DEBUG
        print("   - Original tags: \(task.tags)")
        #endif
        #if DEBUG
        print("   - Tags from notes: \(uniqueTagsFromNotes)")
        #endif
        #if DEBUG
        print("   - Final unique tags: \(finalUniqueTags)")
        #endif
        #if DEBUG
        print("   - User notes (after removing hashtags): '\(userNotes)'")
        #endif
        #if DEBUG
        print("   - Rebuilt notes: '\(rebuiltNotes)'")
        #endif
        
        // Update the task with normalized data
        normalizedTask.notes = rebuiltNotes
        normalizedTask.tags = finalUniqueTags
        
        return normalizedTask
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
        // Also check for #challenge tag which maps to Bin / Challenge quadrant
        let quadrantChecks: [(String, Quadrant)] = [
            ("donow", .doNow),        // Highest priority
            ("delegate", .delegate),
            ("schedule", .schedule),
            ("bin", .bin),            // Bin quadrant
            ("challenge", .bin)        // Challenge tag also maps to Bin / Challenge quadrant
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
                    #if DEBUG
                    print("✅ Found \(tagText) hashtag in reminder: '\(title)'")
                    #endif
                    #if DEBUG
                    print("   Matched: '\(pattern)'")
                    #endif
                    #if DEBUG
                    print("   Notes: '\(notes.prefix(100))'")
                    #endif
                    #if DEBUG
                    print("   Calendar: '\(calendarName)'")
                    #endif
                    #if DEBUG
                    print("   → Assigned to quadrant: \(quadrant.rawValue)")
                    #endif
                    return quadrant
                }
            }
            
            // Also try regex for more complex patterns
            // Pattern: one or more #, optional spaces, then tag text
            let regexPattern = "#+\\s*" + tagText
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if regex.firstMatch(in: lowercased, options: [], range: range) != nil {
                    #if DEBUG
                    print("✅ Found \(tagText) hashtag (regex) in reminder: '\(title)'")
                    #endif
                    #if DEBUG
                    print("   Notes: '\(notes.prefix(100))'")
                    #endif
                    #if DEBUG
                    print("   Calendar: '\(calendarName)'")
                    #endif
                    #if DEBUG
                    print("   → Assigned to quadrant: \(quadrant.rawValue)")
                    #endif
                    return quadrant
                }
            }
        }
        
        // Debug: Print reminder details if no hashtag found (only for first few to avoid spam)
        // But always log if notes are not empty (might have tags we're missing)
        if notes.isEmpty {
            // Only log occasionally for empty notes to avoid spam
            if tasks.count < 5 || tasks.count % 50 == 0 {
                #if DEBUG
                print("⚠️ No quadrant hashtag found in reminder: '\(title)' - skipping")
                #endif
                #if DEBUG
                print("   Notes: (empty)")
                #endif
                #if DEBUG
                print("   Calendar: '\(calendarName)'")
                #endif
            }
        } else {
            // Always log if notes exist but no tag found - might indicate a parsing issue
            #if DEBUG
            print("⚠️ No quadrant hashtag found in reminder: '\(title)' - skipping")
            #endif
            #if DEBUG
            print("   Notes: '\(notes.prefix(200))'")
            #endif
            #if DEBUG
            print("   Calendar: '\(calendarName)'")
            #endif
            #if DEBUG
            print("   Lowercased combined: '\(lowercased.prefix(300))'")
            #endif
        }
        
        // Return nil if no hashtag found - task will be excluded
        return nil
    }
    
    func moveTask(_ task: TaskItem, to quadrant: Quadrant) async {
        guard let reminder = task.reminder else { return }
        
        // Ensure reminder is in iCloud calendar if possible
        if let iCloudCalendar = getiCloudRemindersCalendar(), reminder.calendar != iCloudCalendar {
            reminder.calendar = iCloudCalendar
            #if DEBUG
            print("📅 Moving reminder to iCloud calendar: \(iCloudCalendar.title)")
            #endif
        }
        
        // Preserve existing notes and tags, just update quadrant hashtag
        let notes = reminder.notes ?? ""
        
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
            #if DEBUG
            print("✅ Moved task '\(task.title)' to \(quadrant.rawValue) in calendar: \(reminder.calendar.title)")
            #endif
            // Reload to ensure sync
            await loadReminders()
        } catch {
            let errorMsg = "Error moving reminder: \(error.localizedDescription)"
            #if DEBUG
            print(errorMsg)
            #endif
            lastError = errorMsg
        }
    }
    
    
    func markTaskCompleted(_ task: TaskItem) async {
        if let reminder = task.reminder {
            reminder.isCompleted = !reminder.isCompleted
            
            do {
                try eventStore.save(reminder, commit: true)
                #if DEBUG
                print("✅ Marked task '\(task.title)' as \(reminder.isCompleted ? "completed" : "incomplete")")
                #endif
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error marking reminder as completed: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
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
                #if DEBUG
                print("📅 Moving reminder to iCloud calendar: \(iCloudCalendar.title)")
                #endif
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
                    #if DEBUG
                    print("📅 Updated due date: \(dueDate)")
                    #endif
                } else {
                    // Clear the due date
                    reminder.dueDateComponents = nil
                    #if DEBUG
                    print("📅 Cleared due date")
                    #endif
                }
            } else if let dueDate = dueDate {
                // This is from another view - only set if provided
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                reminder.dueDateComponents = components
                #if DEBUG
                print("📅 Updated due date: \(dueDate)")
                #endif
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
                #if DEBUG
                print("✅ Updated task '\(title ?? task.title)' in calendar: \(reminder.calendar.title)")
                #endif
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error updating reminder: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
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
    
    func getTasksForQuadrant(_ quadrant: Quadrant, showCompleted: Bool = true, showOnlyToday: Bool = false, showOnlyThisWeek: Bool = false, showOnlyDelegated: Bool = false, filterByDelegate: Delegate? = nil, showUndelegatedOnly: Bool = false) -> [TaskItem] {
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
        
        // Filter by delegated tasks
        if showOnlyDelegated {
            filteredTasks = filteredTasks.filter { task in
                hasDelegateTag(task)
            }
        }
        
        // Delegate quadrant: show undelegated only, or filter by selected delegate
        if quadrant == .delegate {
            if showUndelegatedOnly {
                filteredTasks = filteredTasks.filter { !hasDelegateTag($0) }
            } else if let delegate = filterByDelegate {
                filteredTasks = filteredTasks.filter { hasDelegateTag($0, delegate: delegate) }
            }
        }
        
        return filteredTasks
    }
    
    func hasDelegateTag(_ task: TaskItem) -> Bool {
        // Check if task has any tag that matches a delegate short name
        let allTags = task.tags + TaskItem.extractTags(from: task.notes)
        
        // If no delegates loaded, return false
        guard !delegates.isEmpty else {
            return false
        }
        
        // Check if any tag matches any delegate's short name (case-insensitive)
        for tag in allTags {
            let lowerTag = tag.lowercased()
            let tagWithoutHash = lowerTag.hasPrefix("#") ? String(lowerTag.dropFirst()) : lowerTag
            
            for delegate in delegates {
                let lowerShortName = delegate.shortName.lowercased()
                if tagWithoutHash == lowerShortName || lowerTag == "#\(lowerShortName)" {
                    return true
                }
            }
        }
        return false
    }
    
    /// Returns true if the task has this specific delegate's hashtag.
    func hasDelegateTag(_ task: TaskItem, delegate: Delegate) -> Bool {
        let allTags = task.tags + TaskItem.extractTags(from: task.notes)
        let lowerShortName = delegate.shortName.lowercased()
        let hashtag = "#\(lowerShortName)"
        return allTags.contains { tag in
            let lowerTag = tag.lowercased()
            let tagWithoutHash = lowerTag.hasPrefix("#") ? String(lowerTag.dropFirst()) : lowerTag
            return tagWithoutHash == lowerShortName || lowerTag == hashtag
        }
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
                #if DEBUG
                print("✅ Removed time period tag '\(tag)' from task '\(task.title)'")
                #endif
                await loadReminders()
            } catch {
                let errorMsg = "Error removing time period tag: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
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
                #if DEBUG
                print("✅ Set time period tag '\(tag)' for task '\(task.title)'")
                #endif
                await loadReminders()
            } catch {
                let errorMsg = "Error setting time period tag: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
                lastError = errorMsg
            }
        }
    }
    
    func getOldTasks(daysOld: Int = 14) -> [TaskItem] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date()) ?? Date()
        return tasks.filter { $0.lastModified < cutoffDate && !$0.isCompleted }
    }
    
    /// Finds the iCloud Reminders calendar
    private func getBacklogRemindersCalendar() -> EKCalendar? {
        // Get all reminder calendars
        let calendars = eventStore.calendars(for: .reminder)
        
        // Debug: Print all available calendars
        #if DEBUG
        print("📋 Available Reminder Calendars:")
        #endif
        for calendar in calendars {
            #if DEBUG
            print("  - \(calendar.title) (Source: \(calendar.source.title), Type: \(calendar.source.sourceType.rawValue))")
            #endif
        }
        
        // First, look specifically for "Backlog" list
        for calendar in calendars {
            if calendar.title.lowercased() == "backlog" {
                #if DEBUG
                print("✅ Found Backlog calendar: \(calendar.title) from source: \(calendar.source.title)")
                #endif
                return calendar
            }
        }
        
        // If no Backlog found, use the iCloud calendar logic as fallback
        return getiCloudRemindersCalendar()
    }
    
    private func getiCloudRemindersCalendar() -> EKCalendar? {
        // Get all reminder calendars
        let calendars = eventStore.calendars(for: .reminder)
        
        // Look for iCloud calendar first (CalDAV source with iCloud in name)
        for calendar in calendars {
            if calendar.source.sourceType == .calDAV {
                let sourceTitle = calendar.source.title.lowercased()
                // iCloud calendars can have various names like "iCloud", "iCloud Account", etc.
                if sourceTitle.contains("icloud") {
                    #if DEBUG
                    print("✅ Found iCloud calendar: \(calendar.title) from source: \(calendar.source.title)")
                    #endif
                    return calendar
                }
            }
        }
        
        // Also check for local calendars that might be syncing to iCloud
        // On iOS, the default might already be iCloud if that's what's configured
        if let defaultCalendar = eventStore.defaultCalendarForNewReminders() {
            let sourceTitle = defaultCalendar.source.title.lowercased()
            if sourceTitle.contains("icloud") || defaultCalendar.source.sourceType == .calDAV {
                #if DEBUG
                print("✅ Default calendar is iCloud: \(defaultCalendar.title)")
                #endif
                return defaultCalendar
            }
        }
        
        #if DEBUG
        print("⚠️ No iCloud calendar found. Available calendars:")
        #endif
        for calendar in calendars {
            #if DEBUG
            print("  - \(calendar.title) (Source: \(calendar.source.title))")
            #endif
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
            #if DEBUG
            print(errorMsg)
            #endif
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
        
        // Get the Backlog calendar for reminders, fallback to iCloud, then default
        var calendar = getBacklogRemindersCalendar()
        if calendar == nil {
            calendar = getiCloudRemindersCalendar()
        }
        if calendar == nil {
            calendar = eventStore.defaultCalendarForNewReminders()
        }
        
        guard let calendar = calendar else {
            let errorMsg = "No calendar available. Please check your Reminders app settings and ensure iCloud is enabled."
            #if DEBUG
            print(errorMsg)
            #endif
            lastError = errorMsg
            return
        }
        
        #if DEBUG
        print("📅 Using calendar: \(calendar.title) (Source: \(calendar.source.title))")
        #endif
        
        // Validate task title is not empty
        let trimmedTitle = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            let errorMsg = "Task title cannot be empty"
            #if DEBUG
            print("❌ \(errorMsg)")
            #endif
            lastError = errorMsg
            return
        }
        
        // Create a new reminder in EventKit
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = trimmedTitle
        
        // Normalize task to ensure tags are in both notes and tags field, with no duplicates
        let normalizedTask = normalizeTaskTagsAndNotes(task)
        
        // Use normalized notes - this ensures all tags are in the notes field
        let finalNotes = normalizedTask.notes
        reminder.notes = finalNotes
        
        // Ensure notes is not nil (EventKit requires non-nil)
        if reminder.notes == nil {
            reminder.notes = ""
        }
        
        // Try to set tags using iOS 17+ API if available
        // Note: EventKit doesn't have a direct tags property, but we can try using URL scheme or other methods
        // For now, tags are stored in notes as hashtags, which is the standard workaround
        // Apple Reminders' native tag field may not be accessible via EventKit API
        if #available(iOS 17.0, macOS 14.0, *) {
            // iOS 17+ might have tag support, but EventKit API doesn't expose it directly
            // Tags are stored in notes as hashtags which Apple Reminders can parse
            #if DEBUG
            print("📱 iOS 17+ detected - tags stored in notes as hashtags")
            #endif
        }
        
        // Debug: Print tag information
        #if DEBUG
        print("🏷️ Original task:")
        #endif
        #if DEBUG
        print("   - Tags: \(task.tags)")
        #endif
        #if DEBUG
        print("   - Notes: \(task.notes)")
        #endif
        #if DEBUG
        print("🏷️ Normalized task:")
        #endif
        #if DEBUG
        print("   - Tags: \(normalizedTask.tags)")
        #endif
        #if DEBUG
        print("   - Notes: \(normalizedTask.notes)")
        #endif
        #if DEBUG
        print("🏷️ Reminder notes being saved: \(reminder.notes ?? "nil")")
        #endif
        reminder.calendar = calendar
        
        // Set due date if provided
        if let dueDate = dueDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
            reminder.dueDateComponents = components
            #if DEBUG
            print("📅 Set due date: \(dueDate)")
            #endif
        }
        
        do {
            try eventStore.save(reminder, commit: true)
            #if DEBUG
            print("✅ Successfully created reminder: \(task.title)")
            #endif
            #if DEBUG
            print("📝 Reminder ID: \(reminder.calendarItemIdentifier)")
            #endif
            #if DEBUG
            print("📅 Calendar: \(reminder.calendar?.title ?? "unknown")")
            #endif
            #if DEBUG
            print("🏷️ Notes saved to reminder: \(reminder.notes ?? "none")")
            #endif
            #if DEBUG
            print("🏷️ Tags in normalized task: \(normalizedTask.tags)")
            #endif
            
            // Verify the reminder was saved correctly by reading it back
            if let savedReminder = eventStore.calendarItem(withIdentifier: reminder.calendarItemIdentifier) as? EKReminder {
                #if DEBUG
                print("🔍 Verification - Saved reminder notes: \(savedReminder.notes ?? "none")")
                #endif
            }
            
            lastError = nil
            // Reload reminders to ensure sync
            await loadReminders()
            #if DEBUG
            print("🔄 Reminders reloaded after task creation")
            #endif
        } catch {
            let errorMsg = "Error creating reminder: \(error.localizedDescription)"
            #if DEBUG
            print("❌ \(errorMsg)")
            #endif
            #if DEBUG
            print("Full error: \(error)")
            #endif
            if let nsError = error as NSError? {
                #if DEBUG
                print("Error domain: \(nsError.domain), code: \(nsError.code)")
                #endif
                #if DEBUG
                print("Error userInfo: \(nsError.userInfo)")
                #endif
            }
            lastError = errorMsg
        }
    }
    
    func deleteTask(_ task: TaskItem) async {
        if let reminder = task.reminder {
            do {
                try eventStore.remove(reminder, commit: true)
                #if DEBUG
                print("✅ Deleted task '\(task.title)'")
                #endif
                // Reload to ensure sync
                await loadReminders()
            } catch {
                let errorMsg = "Error deleting reminder: \(error.localizedDescription)"
                #if DEBUG
                print(errorMsg)
                #endif
                lastError = errorMsg
            }
        } else {
            // Remove from local tasks if it's not a reminder
            tasks.removeAll { $0.id == task.id }
        }
    }
    
    // MARK: - Prepare reminders (Coach → Prepare answers into lists: today, this week, this month, this quarter)
    
    /// Adds Prepare reminders to the given list. Title format: "Prepare-Question-Date"; detail (answer only) in notes.
    func addPrepareReminders(listName: String, questionAnswerPairs: [(question: String, answer: String)]) async throws {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        guard isAuthorized else {
            throw NSError(domain: "RemindersManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authorized to access reminders."])
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task.detached(priority: .userInitiated) {
                let store = EKEventStore()
                let result = Result<Void, Error> {
                    try Self.addPrepareRemindersSync(store: store, listName: listName, questionAnswerPairs: questionAnswerPairs)
                }
                switch result {
                case .success:
                    await MainActor.run {
                        self.lastError = nil
                        Task { await self.loadReminders() }
                        continuation.resume()
                    }
                case .failure(let error):
                    await MainActor.run {
                        self.lastError = (error as NSError).localizedDescription
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Performs the actual EventKit work on a background thread. Title: "Prepare-Question-Date"; notes: detail (answer) only.
    private nonisolated static func addPrepareRemindersSync(store: EKEventStore, listName: String, questionAnswerPairs: [(question: String, answer: String)]) throws {
        let calendars = store.calendars(for: .reminder)
        let listNameLower = listName.lowercased()
        guard let calendar = calendars.first(where: { $0.title.lowercased() == listNameLower }) else {
            throw NSError(domain: "RemindersManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Reminder list \"\(listName)\" not found. Create a list named \"\(listName)\" in the Reminders app."])
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yy"
        let dateString = dateFormatter.string(from: Date())
        for (_, (question, answer)) in questionAnswerPairs.enumerated() {
            let answerTrimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            let questionForTitle = question.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            let reminder = EKReminder(eventStore: store)
            reminder.title = "Prepare-\(questionForTitle)-\(dateString)"
            reminder.notes = answerTrimmed
            reminder.calendar = calendar
            try store.save(reminder, commit: true)
            #if DEBUG
            print("✅ Prepare reminder added to \(calendar.title): \(reminder.title ?? "")")
            #endif
        }
    }
    
    /// Fetches "Prepare-" reminders from the given list (e.g. "today"). Title format: Prepare-Question-Date; notes = detail (answer).
    /// - Parameters:
    ///   - incompleteOnly: if true, only return reminders that are not completed.
    ///   - todayOnly: if true, only return reminders whose title ends with today's date (d MMM yy).
    func fetchPrepareReminders(listName: String, incompleteOnly: Bool = false, todayOnly: Bool = false) async -> [(question: String, answer: String)] {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        guard isAuthorized else { return [] }
        let calendars = eventStore.calendars(for: .reminder)
        let listNameLower = listName.lowercased()
        guard let calendar = calendars.first(where: { $0.title.lowercased() == listNameLower }) else { return [] }
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            eventStore.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM yy"
        let todayString = dateFormatter.string(from: Date())
        let prefix = "Prepare-"
        var result: [(question: String, answer: String)] = []
        for r in reminders {
            guard let title = r.title, title.hasPrefix(prefix) else { continue }
            if incompleteOnly, r.isCompleted { continue }
            if todayOnly, !title.hasSuffix("-" + todayString) { continue }
            let question = Self.prepareQuestionFromTitle(title, prefix: prefix)
            let answer = (r.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            result.append((question: question, answer: answer))
        }
        return result
    }

    /// Extracts question from reminder title "Prepare-Question-Date" by stripping prefix and trailing "-d MMM yy".
    private static func prepareQuestionFromTitle(_ title: String, prefix: String) -> String {
        let afterPrefix = title.hasPrefix(prefix) ? String(title.dropFirst(prefix.count)) : title
        guard let range = afterPrefix.range(of: #"-\d{1,2} [A-Za-z]{3} \d{2}$"#, options: .regularExpression) else {
            return afterPrefix.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(afterPrefix[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Call when starting a Prepare session for Today: completes any Prepare reminders from before today, returns today's (same day) for prefilling the form.
    func prepareSessionForToday(listName: String) async -> [(question: String, answer: String)] {
        let currentStatus = EKEventStore.authorizationStatus(for: .reminder)
        let isAuthorized: Bool
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = currentStatus == .fullAccess
        } else {
            isAuthorized = currentStatus == .authorized
        }
        guard isAuthorized else { return [] }
        let calendars = eventStore.calendars(for: .reminder)
        let listNameLower = listName.lowercased()
        guard let calendar = calendars.first(where: { $0.title.lowercased() == listNameLower }) else { return [] }
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = await withCheckedContinuation { (continuation: CheckedContinuation<[EKReminder], Never>) in
            eventStore.fetchReminders(matching: predicate) { continuation.resume(returning: $0 ?? []) }
        }
        let prefix = "Prepare-"
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        var fromToday: [(created: Date, question: String, answer: String)] = []
        for r in reminders {
            guard let title = r.title, title.hasPrefix(prefix) else { continue }
            let created = r.creationDate ?? .distantPast
            if created < startOfToday {
                if !r.isCompleted {
                    r.isCompleted = true
                    try? eventStore.save(r, commit: true)
                }
                continue
            }
            let question = Self.prepareQuestionFromTitle(title, prefix: prefix)
            let answer = (r.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            fromToday.append((created: created, question: question, answer: answer))
        }
        fromToday.sort { $0.created < $1.created }
        return fromToday.map { ($0.question, $0.answer) }
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
            #if DEBUG
            print("❌ Not authorized to load delegates")
            #endif
            return
        }
        
        // Find the "Delegates" list
        let calendars = eventStore.calendars(for: .reminder)
        guard let delegatesCalendar = calendars.first(where: { $0.title.lowercased() == "delegates" }) else {
            #if DEBUG
            print("⚠️ Delegates list not found")
            #endif
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
        
        // Extract delegates from reminders
        // Title = short name (for hashtag), Notes = full name (for display)
        var loadedDelegates: [Delegate] = []
        for reminder in reminders {
            guard let shortName = reminder.title, !shortName.isEmpty else { continue }
            let fullName = reminder.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let delegate = Delegate(shortName: shortName, fullName: fullName)
            loadedDelegates.append(delegate)
        }
        
        // Sort by display name
        delegates = loadedDelegates.sorted { $0.displayName < $1.displayName }
        #if DEBUG
        print("✅ Loaded \(delegates.count) delegates:")
        #endif
        for delegate in delegates {
            #if DEBUG
            print("   - \(delegate.displayName) (\(delegate.shortName))")
            #endif
        }
    }
    
    func addDelegate(shortName: String, fullName: String) async {
        let trimmedShortName = shortName.trimmingCharacters(in: .whitespaces)
        guard !trimmedShortName.isEmpty else { return }
        
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
                #if DEBUG
                print("✅ Created Delegates list")
                #endif
            } catch {
                lastError = "Failed to create Delegates list: \(error.localizedDescription)"
                #if DEBUG
                print("❌ \(lastError ?? "")")
                #endif
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
        
        if existingReminders.contains(where: { $0.title?.lowercased() == trimmedShortName.lowercased() }) {
            #if DEBUG
            print("⚠️ Delegate with short name '\(trimmedShortName)' already exists")
            #endif
            await loadDelegates()
            return
        }
        
        // Create a new reminder for the delegate
        // Title = short name (for hashtag), Notes = full name (for display)
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = trimmedShortName
        reminder.notes = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        reminder.calendar = calendar
        
        do {
            try eventStore.save(reminder, commit: true)
            #if DEBUG
            print("✅ Added delegate: \(fullName.isEmpty ? trimmedShortName : fullName) (\(trimmedShortName))")
            #endif
            await loadDelegates()
        } catch {
            lastError = "Failed to add delegate: \(error.localizedDescription)"
            #if DEBUG
            print("❌ \(lastError ?? "")")
            #endif
        }
    }
    
    func removeDelegate(_ delegate: Delegate) async {
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
        
        guard let reminder = reminders.first(where: { $0.title?.lowercased() == delegate.shortName.lowercased() }) else {
            lastError = "Delegate not found"
            return
        }
        
        do {
            try eventStore.remove(reminder, commit: true)
            #if DEBUG
            print("✅ Removed delegate: \(delegate.displayName)")
            #endif
            await loadDelegates()
        } catch {
            lastError = "Failed to remove delegate: \(error.localizedDescription)"
            #if DEBUG
            print("❌ \(lastError ?? "")")
            #endif
        }
    }
    
    func updateDelegate(_ delegate: Delegate, newShortName: String, newFullName: String) async {
        let trimmedShortName = newShortName.trimmingCharacters(in: .whitespaces)
        guard !trimmedShortName.isEmpty else { return }
        
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
        
        guard let reminder = reminders.first(where: { $0.title?.lowercased() == delegate.shortName.lowercased() }) else {
            lastError = "Delegate not found"
            return
        }
        
        // Check if new short name conflicts with existing delegate
        if trimmedShortName.lowercased() != delegate.shortName.lowercased() {
            if reminders.contains(where: { $0.title?.lowercased() == trimmedShortName.lowercased() }) {
                lastError = "A delegate with short name '\(trimmedShortName)' already exists"
                #if DEBUG
                print("❌ \(lastError ?? "")")
                #endif
                return
            }
        }
        
        reminder.title = trimmedShortName
        reminder.notes = newFullName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            try eventStore.save(reminder, commit: true)
            #if DEBUG
            print("✅ Updated delegate: \(delegate.displayName) → \(newFullName.isEmpty ? trimmedShortName : newFullName) (\(trimmedShortName))")
            #endif
            await loadDelegates()
        } catch {
            lastError = "Failed to update delegate: \(error.localizedDescription)"
            #if DEBUG
            print("❌ \(lastError ?? "")")
            #endif
        }
    }
}

