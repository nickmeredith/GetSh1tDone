import SwiftUI

struct EisenhowerMatrixView: View {
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var draggedTask: TaskItem?
    @State private var showingTaskDetail: TaskItem?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GetSh1tDone")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                Button(action: {
                    Task {
                        await remindersManager.loadReminders()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                }
                .padding()
            }
            .background(Color(.systemBackground))
            
            // Matrix Grid
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        // Top Row
                        QuadrantView(
                            quadrant: .doNow,
                            tasks: remindersManager.getTasksForQuadrant(.doNow),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .delegate,
                            tasks: remindersManager.getTasksForQuadrant(.delegate),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                    }
                    
                    HStack(spacing: 0) {
                        // Bottom Row
                        QuadrantView(
                            quadrant: .schedule,
                            tasks: remindersManager.getTasksForQuadrant(.schedule),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .bin,
                            tasks: remindersManager.getTasksForQuadrant(.bin),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                    }
                }
            }
        }
        .sheet(item: $showingTaskDetail) { task in
            TaskDetailView(task: task, remindersManager: remindersManager)
        }
        .task {
            if remindersManager.authorizationStatus == .notDetermined {
                try? await remindersManager.requestAccess()
            }
            await remindersManager.loadReminders()
        }
    }
}

struct QuadrantView: View {
    let quadrant: Quadrant
    let tasks: [TaskItem]
    let allTasks: [TaskItem]
    let geometry: GeometryProxy
    @ObservedObject var remindersManager: RemindersManager
    let onTaskTap: (TaskItem) -> Void
    
    @State private var isTargeted = false
    @State private var showingAddTask = false
    @State private var showingEditTask: TaskItem?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(quadrant.rawValue)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(quadrantColor)
                    Text(quadrant.description)
                        .font(.caption)
                        .foregroundColor(quadrantColor.opacity(0.8))
                }
                
                Spacer()
                
                Text("\(tasks.count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(quadrantColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(quadrantColor.opacity(0.1))
            
            // Tasks
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(tasks) { task in
                        TaskCard(
                            task: task,
                            quadrantColor: quadrantColor,
                            onTap: { onTaskTap(task) },
                            onEdit: { showingEditTask = task },
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
                        .draggable(task.id) {
                            TaskCard(task: task, quadrantColor: quadrantColor, onTap: {}, onEdit: {}, onDelete: {}, onToggleComplete: {})
                                .opacity(0.5)
                        }
                    }
                    
                    // Add Task Button
                    Button(action: { showingAddTask = true }) {
                        HStack {
                            Image(systemName: "plus")
                                .foregroundColor(quadrantColor)
                            Text("Add Task")
                                .foregroundColor(quadrantColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                .foregroundColor(quadrantColor.opacity(0.3))
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
            }
        }
        .frame(width: geometry.size.width / 2, height: geometry.size.height / 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 1.0, green: 0.95, blue: 0.95))
        )
        .dropDestination(for: String.self) { droppedIds, _ in
            guard let droppedId = droppedIds.first,
                  let task = allTasks.first(where: { $0.id == droppedId }) else {
                return false
            }
            
            if task.quadrant != quadrant {
                Task {
                    await remindersManager.moveTask(task, to: quadrant)
                }
                return true
            }
            return false
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(quadrant: quadrant, remindersManager: remindersManager)
        }
        .sheet(item: $showingEditTask) { task in
            EditTaskView(task: task, remindersManager: remindersManager)
        }
    }
    
    private var quadrantColor: Color {
        switch quadrant {
        case .doNow: return Color(red: 0.8, green: 0.2, blue: 0.2)
        case .delegate: return .orange
        case .schedule: return .blue
        case .bin: return .gray
        }
    }
}

struct TaskCard: View {
    let task: TaskItem
    let quadrantColor: Color
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleComplete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? .gray : .gray.opacity(0.5))
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // Task Content
            VStack(alignment: .leading, spacing: 8) {
                // Task Title
                Text(task.title)
                    .font(.body)
                    .foregroundColor(task.isCompleted ? .gray.opacity(0.6) : .primary)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Tags
                if !task.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(task.tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                Text(tag)
                                    .font(.caption)
                            }
                            .foregroundColor(.gray.opacity(0.7))
                        }
                    }
                }
            }
            
            // Action Buttons
            HStack(spacing: 8) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.gray.opacity(0.7))
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    let quadrant: Quadrant
    @ObservedObject var remindersManager: RemindersManager
    
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var tags: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Task Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section("Tags") {
                    TextField("Enter tags (e.g., #urgent #important)", text: $tags)
                        .autocapitalization(.none)
                }
                
                Section("Quadrant") {
                    Text(quadrant.rawValue)
                    Text(quadrant.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let tagArray = tags.components(separatedBy: " ")
                            .filter { $0.hasPrefix("#") }
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        let task = TaskItem(
                            title: title,
                            notes: notes,
                            quadrant: quadrant,
                            tags: tagArray
                        )
                        
                        Task {
                            await remindersManager.addTask(task)
                            dismiss()
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
    }
}

struct EditTaskView: View {
    @Environment(\.dismiss) var dismiss
    let task: TaskItem
    @ObservedObject var remindersManager: RemindersManager
    
    @State private var title: String
    @State private var notes: String
    @State private var tags: String
    
    init(task: TaskItem, remindersManager: RemindersManager) {
        self.task = task
        self.remindersManager = remindersManager
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes.replacingOccurrences(of: task.quadrant.hashtag, with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        _tags = State(initialValue: task.tags.joined(separator: " "))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section("Tags") {
                    TextField("Enter tags", text: $tags)
                        .autocapitalization(.none)
                }
                
                Section("Quadrant") {
                    Text("Current: \(task.quadrant.rawValue)")
                    Text(task.quadrant.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let tagArray = tags.components(separatedBy: " ")
                            .filter { $0.hasPrefix("#") }
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        var updatedTask = task
                        updatedTask.title = title
                        updatedTask.notes = notes
                        updatedTask.tags = tagArray
                        
                        Task {
                            await remindersManager.updateTask(updatedTask, title: title, notes: notes)
                            dismiss()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
    }
}

struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    let task: TaskItem
    @ObservedObject var remindersManager: RemindersManager
    
    @State private var title: String
    @State private var notes: String
    
    init(task: TaskItem, remindersManager: RemindersManager) {
        self.task = task
        self.remindersManager = remindersManager
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes.replacingOccurrences(of: task.quadrant.hashtag, with: "").trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
                
                Section("Quadrant") {
                    Text("Current: \(task.quadrant.rawValue)")
                    Text(task.quadrant.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Edit Task")
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
                            await remindersManager.updateTask(task, title: title, notes: notes)
                            dismiss()
                        }
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 500, height: 400)
        #endif
    }
}

