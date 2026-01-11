import SwiftUI

struct PrioritiesView: View {
    @AppStorage("priorities") private var prioritiesData: Data = Data()
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var priorities: [Priority] = []
    @State private var showingAddPriority = false
    @State private var newPriorityText = ""
    @State private var lastReviewDate: Date?
    @State private var selectedTimePeriod: TimePeriod = .today
    @State private var showingEditTask: TaskItem?
    @State private var showingTaskDetail: TaskItem?
    
    enum TimePeriod: String, CaseIterable {
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        case thisQuarter = "This Quarter"
        
        var tag: String {
            switch self {
            case .today: return "#today"
            case .thisWeek: return "#thisweek"
            case .thisMonth: return "#thismonth"
            case .thisQuarter: return "#thisquarter"
            }
        }
    }
    
    struct Priority: Identifiable, Codable, Equatable {
        var id = UUID()
        var text: String
        var createdAt: Date
        var lastReviewed: Date?
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Time Period Tabs
                Picker("Time Period", selection: $selectedTimePeriod) {
                    ForEach(TimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Tasks List for selected time period
                let filteredTasks = getTasksForTimePeriod(selectedTimePeriod)
                
                if filteredTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No tasks for \(selectedTimePeriod.rawValue)")
                            .font(.title2)
                        Text("Add tasks with the \(selectedTimePeriod.tag) tag to see them here")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            TaskRowView(
                                task: task,
                                onTap: {
                                    showingTaskDetail = task
                                },
                                onEdit: {
                                    showingEditTask = task
                                },
                                onDelete: {
                                    Task {
                                        await remindersManager.deleteTask(task)
                                    }
                                },
                                onToggleComplete: {
                                    Task {
                                        await remindersManager.markTaskCompleted(task)
                                    }
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Plan")
            .sheet(item: $showingEditTask) { task in
                EditTaskView(task: task, remindersManager: remindersManager)
            }
            .sheet(item: $showingTaskDetail) { task in
                TaskDetailView(task: task, remindersManager: remindersManager)
            }
        }
    }
    
    private func getTasksForTimePeriod(_ period: TimePeriod) -> [TaskItem] {
        let allTasks = remindersManager.tasks.filter { !$0.isCompleted }
        let timePeriodTags = ["#today", "#thisweek", "#thismonth", "#thisquarter"]
        
        return allTasks.filter { task in
            let allTags = task.tags + TaskItem.extractTags(from: task.notes)
            let lowerTag = period.tag.lowercased()
            
            // For "This Week", include both #thisweek and #today
            if period == .thisWeek {
                return allTags.contains { tag in
                    let lower = tag.lowercased()
                    return lower == "#thisweek" || lower == "#today"
                }
            }
            
            return allTags.contains { $0.lowercased() == lowerTag }
        }
    }
    
    private func addPriority() {
        guard !newPriorityText.trimmingCharacters(in: .whitespaces).isEmpty,
              priorities.count < 5 else { return }
        
        let priority = Priority(
            text: newPriorityText.trimmingCharacters(in: .whitespaces),
            createdAt: Date(),
            lastReviewed: nil
        )
        priorities.append(priority)
        newPriorityText = ""
        showingAddPriority = false
    }
    
    private func deletePriority(at offsets: IndexSet) {
        priorities.remove(atOffsets: offsets)
    }
    
    private func reviewPriorities() {
        lastReviewDate = Date()
        for index in priorities.indices {
            priorities[index].lastReviewed = Date()
        }
    }
    
    private func loadPriorities() {
        if let decoded = try? JSONDecoder().decode([Priority].self, from: prioritiesData) {
            priorities = decoded
        }
        
        // Load last review date
        if let reviewDate = UserDefaults.standard.object(forKey: "lastPriorityReview") as? Date {
            lastReviewDate = reviewDate
        }
    }
    
    private func savePriorities() {
        if let encoded = try? JSONEncoder().encode(priorities) {
            prioritiesData = encoded
        }
        
        if let reviewDate = lastReviewDate {
            UserDefaults.standard.set(reviewDate, forKey: "lastPriorityReview")
        }
    }
}

struct TaskRowView: View {
    let task: TaskItem
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                
                // Quadrant badge
                HStack(spacing: 6) {
                    Text(task.quadrant.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(quadrantColor.opacity(0.2))
                        .foregroundColor(quadrantColor)
                        .cornerRadius(4)
                    
                    // Tags
                    if !task.tags.isEmpty {
                        ForEach(task.tags.prefix(2), id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var quadrantColor: Color {
        switch task.quadrant {
        case .doNow: return Color(red: 1.0, green: 0.4, blue: 0.4)
        case .delegate: return Color(red: 1.0, green: 0.7, blue: 0.3)
        case .schedule: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case .bin: return Color(red: 0.6, green: 0.6, blue: 0.6)
        }
    }
}

struct AddPriorityView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var newPriorityText: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Priority") {
                    TextField("Enter your priority", text: $newPriorityText, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Add Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .disabled(newPriorityText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 200)
        #endif
    }
}

