import SwiftUI

// MARK: - Prepare period and questions

enum PreparePeriod: String, CaseIterable, Identifiable {
    case day = "Today"
    case week = "This Week"
    case month = "This Month"
    case quarter = "This Quarter"

    var id: String { rawValue }

    /// Title shown in the app (e.g. "DAILY PREP (2 minutes)").
    var sectionTitle: String {
        switch self {
        case .day: return "DAILY PREP (2 minutes)"
        case .week: return "WEEKLY PREP (5–10 minutes)"
        case .month: return "MONTHLY PREP (15 minutes)"
        case .quarter: return "QUARTERLY PREP (30–45 minutes)"
        }
    }

    /// Reminder list name to add Prepare reminders to (user has lists: today, this week, this month, this quarter).
    var reminderListName: String {
        switch self {
        case .day: return "today"
        case .week: return "this week"
        case .month: return "this month"
        case .quarter: return "this quarter"
        }
    }

    /// Questions for this period (in order).
    var questions: [String] {
        switch self {
        case .day:
            return [
                "What is the One Thing that makes today a win?",
                "What will I protect time for today?",
                "What is the most likely distraction, and how will I handle it?"
            ]
        case .week:
            return [
                "What are the 3 outcomes that matter this week?",
                "Which days need deep focus?",
                "What must I not start this week?"
            ]
        case .month:
            return [
                "What progress do I want to see by month-end?",
                "What must be true for this month to be successful?",
                "What am I willing to deprioritise?"
            ]
        case .quarter:
            return [
                "What are the 3–5 outcomes that define success this quarter?",
                "Which goals does this quarter serve?",
                "What constraints do I need to design around?",
                "What will I deliberately not pursue?"
            ]
        }
    }

}

// MARK: - Prepare result (for adding to Reminders)

struct PrepareResult {
    let period: PreparePeriod
    let writtenAt: Date
    let answers: [(question: String, answer: String)]
}
