import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct EisenhowerMatrixView: View {
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var draggedTask: TaskItem?
    @State private var showingTaskDetail: TaskItem?
    @State private var showingError: String?
    @State private var showCompletedTasks = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GetSh1tDone")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Spacer()
                
                // Toggle for completed tasks
                HStack(spacing: 8) {
                    Image(systemName: showCompletedTasks ? "eye.fill" : "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Toggle("Show Completed", isOn: $showCompletedTasks)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground).opacity(0.8))
                .cornerRadius(8)
                
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
                            tasks: remindersManager.getTasksForQuadrant(.doNow, showCompleted: showCompletedTasks),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .schedule,
                            tasks: remindersManager.getTasksForQuadrant(.schedule, showCompleted: showCompletedTasks),
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
                            quadrant: .delegate,
                            tasks: remindersManager.getTasksForQuadrant(.delegate, showCompleted: showCompletedTasks),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .bin,
                            tasks: remindersManager.getTasksForQuadrant(.bin, showCompleted: showCompletedTasks),
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(item: $showingTaskDetail) { task in
            TaskDetailView(task: task, remindersManager: remindersManager)
        }
        .task {
            if remindersManager.authorizationStatus == .notDetermined {
                do {
                    try await remindersManager.requestAccess()
                } catch {
                    showingError = "Failed to get Reminders access: \(error.localizedDescription)"
                }
            }
            await remindersManager.loadReminders()
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh when app comes to foreground to catch external changes
            Task {
                await remindersManager.loadReminders()
            }
        }
        #elseif os(macOS)
        .onReceive(NSApplication.willBecomeActiveNotification) { _ in
            // Refresh when app becomes active to catch external changes
            Task {
                await remindersManager.loadReminders()
            }
        }
        #endif
        .onChange(of: remindersManager.lastError) { error in
            if let error = error {
                showingError = error
            }
        }
        .alert("Error", isPresented: Binding(
            get: { showingError != nil },
            set: { if !$0 { showingError = nil } }
        )) {
            Button("OK") {
                showingError = nil
            }
        } message: {
            if let error = showingError {
                Text(error)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { showingError != nil },
            set: { if !$0 { showingError = nil } }
        )) {
            Button("OK") {
                showingError = nil
            }
        } message: {
            if let error = showingError {
                Text(error)
            }
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
        GeometryReader { quadrantGeometry in
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
                
                // Tasks - ScrollView with calculated height
                let headerHeight: CGFloat = 60 // Approximate header height
                let availableHeight = quadrantGeometry.size.height - headerHeight
                
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 6) {
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
                                TaskCard(
                                    task: task,
                                    quadrantColor: quadrantColor,
                                    onTap: {},
                                    onEdit: {},
                                    onDelete: {},
                                    onToggleComplete: {}
                                )
                                .opacity(0.6)
                                .scaleEffect(0.9)
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
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
                .frame(height: max(0, availableHeight))
            }
        }
        .frame(width: geometry.size.width / 2, height: geometry.size.height / 2)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? quadrantColor.opacity(0.15) : Color(red: 1.0, green: 0.95, blue: 0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTargeted ? quadrantColor : Color.clear, lineWidth: isTargeted ? 3 : 0)
                )
        )
        .dropDestination(for: String.self) { droppedIds, location in
            guard let droppedId = droppedIds.first,
                  let task = allTasks.first(where: { $0.id == droppedId }) else {
                return false
            }
            
            if task.quadrant != quadrant {
                // Provide haptic feedback
                #if os(iOS)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #elseif os(macOS)
                // macOS doesn't have haptic feedback, but we can use a system sound
                NSSound.beep()
                #endif
                
                Task {
                    await remindersManager.moveTask(task, to: quadrant)
                }
                return true
            }
            return false
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.2)) {
                isTargeted = targeted
            }
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
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Swipe threshold - how far to swipe before completing
    private let swipeThreshold: CGFloat = 100
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Task Content (more compact)
            VStack(alignment: .leading, spacing: 4) {
                // Task Title - smaller font
                Text(task.title)
                    .font(.system(size: 13))
                    .foregroundColor(task.isCompleted ? .gray.opacity(0.6) : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Tags - smaller
                if !task.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(task.tags, id: \.self) { tag in
                            HStack(spacing: 2) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 8))
                                Text(tag)
                                    .font(.system(size: 10))
                            }
                            .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                }
            }
            
            // Action Buttons - smaller and more compact
            HStack(spacing: 6) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray.opacity(0.6))
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
        .offset(x: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Only allow swiping right (positive translation)
                    if value.translation.width > 0 {
                        dragOffset = value.translation.width
                        isDragging = true
                    }
                }
                .onEnded { value in
                    // If swiped far enough to the right, complete the task
                    if value.translation.width > swipeThreshold && !task.isCompleted {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                        onToggleComplete()
                        
                        // Haptic feedback
                        #if os(iOS)
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        #endif
                    } else {
                        // Spring back to original position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                    isDragging = false
                }
        )
        .onTapGesture {
            onTap()
        }
        .overlay(
            // Visual feedback when swiping
            Group {
                if isDragging && dragOffset > 0 {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                            .opacity(min(dragOffset / swipeThreshold, 1.0))
                            .padding(.trailing, 12)
                    }
                }
            }
        )
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
                
                Section("Tags") {
                    if task.tags.isEmpty {
                        Text("No tags")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    } else {
                        ForEach(task.tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                                Text(tag.replacingOccurrences(of: "#", with: ""))
                                    .font(.body)
                            }
                        }
                    }
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

