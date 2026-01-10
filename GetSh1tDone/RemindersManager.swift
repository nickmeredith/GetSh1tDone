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
        
        guard isAuthorized else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        let predicate = eventStore.predicateForReminders(in: nil)
        
        // Use withCheckedContinuation to wrap the completion handler API
        let reminders = await withCheckedContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
        
        var loadedTasks: [TaskItem] = []
        
        for reminder in reminders {
            // Include all reminders, including completed ones
            // Determine quadrant from hashtags in notes
            let quadrant = extractQuadrant(from: reminder)
            var task = TaskItem(reminder: reminder, quadrant: quadrant)
            // Extract tags from notes (excluding quadrant hashtags)
            task.tags = TaskItem.extractTags(from: reminder.notes ?? "")
            loadedTasks.append(task)
        }
        
        tasks = loadedTasks
    }
    
    private func extractQuadrant(from reminder: EKReminder) -> Quadrant {
        let notes = reminder.notes ?? ""
        let title = reminder.title ?? ""
        
        // Check for hashtags in notes or title
        if notes.contains("#DoNow") || title.contains("#DoNow") {
            return .doNow
        } else if notes.contains("#Delegate") || title.contains("#Delegate") {
            return .delegate
        } else if notes.contains("#Schedule") || title.contains("#Schedule") {
            return .schedule
        } else if notes.contains("#Bin") || title.contains("#Bin") {
            return .bin
        }
        
        // Default to Schedule if no hashtag found
        return .schedule
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
        
        // Remove old quadrant hashtags
        Quadrant.allCases.forEach { q in
            notes = notes.replacingOccurrences(of: q.hashtag, with: "")
        }
        
        // Extract and preserve tags (excluding quadrant hashtags)
        let existingTags = TaskItem.extractTags(from: notes)
        notes = notes.replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "DoNow", with: "")
            .replacingOccurrences(of: "Delegate", with: "")
            .replacingOccurrences(of: "Schedule", with: "")
            .replacingOccurrences(of: "Bin", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Rebuild notes: original notes + quadrant hashtag + tags
        var finalNotes = notes
        if !finalNotes.isEmpty {
            finalNotes += "\n\n"
        }
        finalNotes += quadrant.hashtag
        if !existingTags.isEmpty {
            finalNotes += "\n" + existingTags.joined(separator: " ")
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
    
    func updateTask(_ task: TaskItem, title: String?, notes: String?) async {
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
                
                // Add tags if they exist
                if !task.tags.isEmpty {
                    updatedNotes += "\n" + task.tags.joined(separator: " ")
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

