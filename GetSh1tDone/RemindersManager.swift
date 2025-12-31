import Foundation
import EventKit
import Combine

@MainActor
class RemindersManager: ObservableObject {
    private let eventStore = EKEventStore()
    @Published var tasks: [TaskItem] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    
    init() {
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .reminder)
    }
    
    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            // Use new iOS 17+ API
            _ = try await eventStore.requestFullAccessToReminders()
            await MainActor.run {
                checkAuthorizationStatus()
            }
        } else {
            // Fallback for older iOS versions
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
        if #available(iOS 17.0, *) {
            // iOS 17+ uses .fullAccess instead of .authorized
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
        
        // Remove old hashtags
        var notes = reminder.notes ?? ""
        Quadrant.allCases.forEach { q in
            notes = notes.replacingOccurrences(of: q.hashtag, with: "")
        }
        notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add new hashtag
        if !notes.isEmpty {
            notes += "\n\n"
        }
        notes += quadrant.hashtag
        
        reminder.notes = notes
        
        do {
            try eventStore.save(reminder, commit: true)
            
            // Update local task
            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                var updatedTask = tasks[index]
                updatedTask.quadrant = quadrant
                updatedTask.notes = notes
                updatedTask.lastModified = Date()
                tasks[index] = updatedTask
            }
        } catch {
            print("Error saving reminder: \(error)")
        }
    }
    
    
    func markTaskCompleted(_ task: TaskItem) async {
        if let reminder = task.reminder {
            reminder.isCompleted = !reminder.isCompleted
            
            do {
                try eventStore.save(reminder, commit: true)
                await loadReminders()
            } catch {
                print("Error marking reminder as completed: \(error)")
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
            if let title = title {
                reminder.title = title
            }
            
            if let notes = notes {
                let currentHashtag = task.quadrant.hashtag
                var updatedNotes = notes
                if !updatedNotes.contains(currentHashtag) {
                    updatedNotes += "\n\n\(currentHashtag)"
                }
                // Add tags
                if !task.tags.isEmpty {
                    updatedNotes += "\n" + task.tags.joined(separator: " ")
                }
                reminder.notes = updatedNotes
            }
            
            do {
                try eventStore.save(reminder, commit: true)
                await loadReminders()
            } catch {
                print("Error updating reminder: \(error)")
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
            }
        }
    }
    
    func getTasksForQuadrant(_ quadrant: Quadrant) -> [TaskItem] {
        // Show all tasks in quadrant, including completed ones
        tasks.filter { $0.quadrant == quadrant }
    }
    
    func getOldTasks(daysOld: Int = 7) -> [TaskItem] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysOld, to: Date()) ?? Date()
        return tasks.filter { $0.lastModified < cutoffDate && !$0.isCompleted }
    }
    
    func addTask(_ task: TaskItem) async {
        // Create a new reminder in EventKit
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = task.title
        reminder.notes = task.notes + "\n\n" + task.quadrant.hashtag + "\n" + task.tags.joined(separator: " ")
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            await loadReminders()
        } catch {
            print("Error creating reminder: \(error)")
        }
    }
    
    func deleteTask(_ task: TaskItem) async {
        if let reminder = task.reminder {
            do {
                try eventStore.remove(reminder, commit: true)
                await loadReminders()
            } catch {
                print("Error deleting reminder: \(error)")
            }
        } else {
            // Remove from local tasks if it's not a reminder
            tasks.removeAll { $0.id == task.id }
        }
    }
}

