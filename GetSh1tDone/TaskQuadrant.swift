import Foundation
import EventKit

enum Quadrant: String, CaseIterable, Identifiable {
    case doNow = "Do Now"
    case delegate = "Delegate"
    case schedule = "Schedule"
    case bin = "Bin"
    
    var id: String { rawValue }
    
    var hashtag: String {
        switch self {
        case .doNow: return "#DoNow"
        case .delegate: return "#Delegate"
        case .schedule: return "#Schedule"
        case .bin: return "#Bin"
        }
    }
    
    var color: String {
        switch self {
        case .doNow: return "red"
        case .delegate: return "orange"
        case .schedule: return "blue"
        case .bin: return "gray"
        }
    }
    
    var description: String {
        switch self {
        case .doNow: return "Urgent / Important"
        case .delegate: return "Urgent / Not Important"
        case .schedule: return "Not Urgent / Important"
        case .bin: return "Not Urgent / Not Important"
        }
    }
}

struct TaskItem: Identifiable, Equatable {
    let id: String
    var title: String
    var notes: String
    var reminder: EKReminder?
    var quadrant: Quadrant
    var lastModified: Date
    var isCompleted: Bool
    var tags: [String] = []
    
    init(reminder: EKReminder, quadrant: Quadrant) {
        self.id = reminder.calendarItemIdentifier
        self.title = reminder.title ?? ""
        self.notes = reminder.notes ?? ""
        self.reminder = reminder
        self.quadrant = quadrant
        self.lastModified = reminder.lastModifiedDate ?? Date()
        self.isCompleted = reminder.isCompleted
        
        // Extract tags and deduplicate (case-insensitive)
        let extractedTags = Self.extractTags(from: reminder.notes ?? "")
        var seenTags = Set<String>()
        self.tags = extractedTags.compactMap { tag -> String? in
            let lower = tag.lowercased()
            if seenTags.contains(lower) {
                return nil
            }
            seenTags.insert(lower)
            return tag
        }
    }
    
    init(id: String = UUID().uuidString, title: String, notes: String = "", quadrant: Quadrant, tags: [String] = []) {
        self.id = id
        self.title = title
        self.notes = notes
        self.reminder = nil
        self.quadrant = quadrant
        self.lastModified = Date()
        self.isCompleted = false
        self.tags = tags
    }
    
    static func extractTags(from notes: String) -> [String] {
        // Extract all hashtags, handling variations like ##tag, # #tag, etc.
        let normalized = notes
            .replacingOccurrences(of: "##", with: "#")  // Fix double hashes
            .replacingOccurrences(of: "# #", with: "#")  // Fix space before hash
        
        let tagPattern = #"#\w+"#
        let regex = try? NSRegularExpression(pattern: tagPattern, options: [])
        let range = NSRange(normalized.startIndex..., in: normalized)
        let matches = regex?.matches(in: normalized, options: [], range: range) ?? []
        
        // Quadrant hashtags that should be excluded (case-insensitive)
        let quadrantTags = ["#donow", "#delegate", "#schedule", "#bin"]
        
        var seenTags = Set<String>() // Track seen tags (case-insensitive) to avoid duplicates
        let extractedTags = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: normalized) else { return nil }
            let tag = String(normalized[range])
            // Exclude quadrant hashtags (case-insensitive comparison)
            let lowerTag = tag.lowercased()
            if quadrantTags.contains(lowerTag) {
                return nil
            }
            // Check for duplicates (case-insensitive)
            if seenTags.contains(lowerTag) {
                return nil
            }
            seenTags.insert(lowerTag)
            return tag
        }
        
        return extractedTags
    }
}

