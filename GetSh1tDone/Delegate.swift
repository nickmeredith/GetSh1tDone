import Foundation

struct Delegate: Identifiable, Equatable, Hashable, Codable {
    let id: String
    var shortName: String  // Used for hashtag (e.g., "JohnD")
    var fullName: String   // Full name for display (e.g., "John Doe")
    
    init(id: String = UUID().uuidString, shortName: String, fullName: String) {
        self.id = id
        self.shortName = shortName.trimmingCharacters(in: .whitespaces)
        self.fullName = fullName.trimmingCharacters(in: .whitespaces)
    }
    
    // Display name: use full name if available, otherwise short name
    var displayName: String {
        return fullName.isEmpty ? shortName : fullName
    }
    
    // Hashtag format for tagging tasks
    var hashtag: String {
        return "#\(shortName)"
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance
    static func == (lhs: Delegate, rhs: Delegate) -> Bool {
        return lhs.id == rhs.id
    }
}
