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
    @State private var expandedQuadrant: Quadrant?
    @State private var showOnlyToday = false
    @State private var showOnlyThisWeek = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Logo - Productivity themed
                HStack(spacing: 6) {
                    ZStack {
                        // Background circle with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.purple]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 40, height: 40)
                            .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        // Checkmark icon
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    // Lightning bolt for action/speed
                    ZStack {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.orange)
                            .offset(x: -6, y: 0)
                    }
                }
                .padding(.leading)
                
                Spacer()
                
                // Filter toggles
                HStack(spacing: 8) {
                    // Show Today toggle
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                            .foregroundColor(showOnlyToday ? .blue : .secondary)
                        Toggle("Today", isOn: $showOnlyToday)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: showOnlyToday) { newValue in
                                if newValue {
                                    showOnlyThisWeek = false
                                }
                            }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(6)
                    
                    // Show This Week toggle
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.caption2)
                            .foregroundColor(showOnlyThisWeek ? .blue : .secondary)
                        Toggle("This Week", isOn: $showOnlyThisWeek)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .onChange(of: showOnlyThisWeek) { newValue in
                                if newValue {
                                    showOnlyToday = false
                                }
                            }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(6)
                    
                    // Show Completed toggle
                    HStack(spacing: 4) {
                        Image(systemName: showCompletedTasks ? "eye.fill" : "eye.slash.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Toggle("Completed", isOn: $showCompletedTasks)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(6)
                }
                
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
                            tasks: remindersManager.getTasksForQuadrant(.doNow, showCompleted: showCompletedTasks, showOnlyToday: showOnlyToday, showOnlyThisWeek: showOnlyThisWeek),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            showOnlyToday: showOnlyToday,
                            showOnlyThisWeek: showOnlyThisWeek,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            },
                            onExpand: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedQuadrant = .doNow
                                }
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .schedule,
                            tasks: remindersManager.getTasksForQuadrant(.schedule, showCompleted: showCompletedTasks, showOnlyToday: showOnlyToday, showOnlyThisWeek: showOnlyThisWeek),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            showOnlyToday: showOnlyToday,
                            showOnlyThisWeek: showOnlyThisWeek,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            },
                            onExpand: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedQuadrant = .schedule
                                }
                            }
                        )
                    }
                    
                    HStack(spacing: 0) {
                        // Bottom Row
                        QuadrantView(
                            quadrant: .delegate,
                            tasks: remindersManager.getTasksForQuadrant(.delegate, showCompleted: showCompletedTasks, showOnlyToday: showOnlyToday, showOnlyThisWeek: showOnlyThisWeek),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            showOnlyToday: showOnlyToday,
                            showOnlyThisWeek: showOnlyThisWeek,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            },
                            onExpand: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedQuadrant = .delegate
                                }
                            }
                        )
                        
                        QuadrantView(
                            quadrant: .bin,
                            tasks: remindersManager.getTasksForQuadrant(.bin, showCompleted: showCompletedTasks, showOnlyToday: showOnlyToday, showOnlyThisWeek: showOnlyThisWeek),
                            allTasks: remindersManager.tasks,
                            geometry: geometry,
                            remindersManager: remindersManager,
                            showOnlyToday: showOnlyToday,
                            showOnlyThisWeek: showOnlyThisWeek,
                            onTaskTap: { task in
                                showingTaskDetail = task
                            },
                            onExpand: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    expandedQuadrant = .bin
                                }
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            // Full-screen quadrant view
            if let expanded = expandedQuadrant {
                FullScreenQuadrantView(
                    quadrant: expanded,
                    tasks: remindersManager.getTasksForQuadrant(expanded, showCompleted: showCompletedTasks, showOnlyToday: showOnlyToday, showOnlyThisWeek: showOnlyThisWeek),
                    allTasks: remindersManager.tasks,
                    remindersManager: remindersManager,
                    showOnlyToday: showOnlyToday,
                    showOnlyThisWeek: showOnlyThisWeek,
                    onClose: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            expandedQuadrant = nil
                        }
                    },
                    onTaskTap: { task in
                        showingTaskDetail = task
                    }
                )
                .transition(.opacity.combined(with: .scale))
                .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: expandedQuadrant)
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
    let showOnlyToday: Bool
    let showOnlyThisWeek: Bool
    let onTaskTap: (TaskItem) -> Void
    let onExpand: () -> Void
    
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
                    
                    // Expand button
                    Button(action: onExpand) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14))
                            .foregroundColor(quadrantColor)
                            .padding(6)
                            .background(quadrantColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
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
                                },
                                onSetToday: {
                                    Task {
                                        await remindersManager.setTimePeriodTag(task, tag: "#today")
                                    }
                                },
                                onSetThisWeek: {
                                    Task {
                                        await remindersManager.setTimePeriodTag(task, tag: "#thisweek")
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
                                    onToggleComplete: {},
                                    onSetToday: nil,
                                    onSetThisWeek: nil
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
                .fill(isTargeted ? quadrantColor.opacity(0.2) : quadrantColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isTargeted ? quadrantColor : quadrantColor.opacity(0.3), lineWidth: isTargeted ? 3 : 1)
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
        case .doNow: return Color(red: 1.0, green: 0.4, blue: 0.4) // Lighter red
        case .delegate: return Color(red: 1.0, green: 0.7, blue: 0.3) // Lighter orange
        case .schedule: return Color(red: 0.4, green: 0.6, blue: 1.0) // Lighter blue
        case .bin: return Color(red: 0.6, green: 0.6, blue: 0.6) // Lighter gray
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
    let onSetToday: (() -> Void)?
    let onSetThisWeek: (() -> Void)?
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var swipeDirection: SwipeDirection = .none
    
    enum SwipeDirection {
        case none, right, left
    }
    
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
        .overlay(
            // Visual feedback for swipes
            Group {
                if isDragging {
                    if swipeDirection == .right {
                        // Right swipe - set to today
                        HStack {
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .font(.title2)
                                .opacity(min(abs(dragOffset) / swipeThreshold, 1.0))
                                .padding(.trailing, 12)
                        }
                    } else if swipeDirection == .left {
                        // Left swipe - set to this week
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.blue)
                                .font(.title2)
                                .opacity(min(abs(dragOffset) / swipeThreshold, 1.0))
                                .padding(.leading, 12)
                            Spacer()
                        }
                    }
                }
            }
        )
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    // Only respond to horizontal swipes
                    // If vertical movement is greater, don't interfere with scrolling
                    let horizontalMovement = abs(value.translation.width)
                    let verticalMovement = abs(value.translation.height)
                    
                    // Only activate if horizontal movement is significantly greater than vertical (2:1 ratio)
                    if horizontalMovement > verticalMovement * 2 {
                        if value.translation.width > 0 {
                            // Swiping right - set to today
                            dragOffset = min(value.translation.width, swipeThreshold * 1.5)
                            swipeDirection = .right
                            isDragging = true
                        } else if value.translation.width < 0 {
                            // Swiping left - set to this week
                            dragOffset = max(value.translation.width, -swipeThreshold * 1.5)
                            swipeDirection = .left
                            isDragging = true
                        }
                    }
                }
                .onEnded { value in
                    if abs(value.translation.width) > swipeThreshold {
                        if value.translation.width > 0 && swipeDirection == .right {
                            // Swiped right - set to today
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                            onSetToday?()
                            
                            // Haptic feedback
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            #endif
                        } else if value.translation.width < 0 && swipeDirection == .left {
                            // Swiped left - set to this week
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                dragOffset = 0
                            }
                            onSetThisWeek?()
                            
                            // Haptic feedback
                            #if os(iOS)
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            #endif
                        }
                    } else {
                        // Spring back to original position
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                        }
                    }
                    isDragging = false
                    swipeDirection = .none
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
                            await remindersManager.updateTask(updatedTask, title: title, notes: notes, tags: tagArray)
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
    @State private var tags: String
    @State private var dueDate: Date?
    @State private var hasDueDate: Bool
    
    init(task: TaskItem, remindersManager: RemindersManager) {
        self.task = task
        self.remindersManager = remindersManager
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes.replacingOccurrences(of: task.quadrant.hashtag, with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        
        // Extract all tags from notes and combine with task.tags
        let allTagsFromNotes = TaskItem.extractTags(from: task.notes)
        let combinedTags = Array(Set(task.tags + allTagsFromNotes)).sorted()
        _tags = State(initialValue: combinedTags.joined(separator: " "))
        
        // Initialize due date
        if let reminder = task.reminder,
           let dueDateComponents = reminder.dueDateComponents,
           let date = Calendar.current.date(from: dueDateComponents) {
            _dueDate = State(initialValue: date)
            _hasDueDate = State(initialValue: true)
        } else {
            _dueDate = State(initialValue: Date())
            _hasDueDate = State(initialValue: false)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $notes)
                        .frame(height: 130) // Increased from 100 to show 2 more lines
                }
                
                // Time Period Selection - moved right after notes
                Section("Time Period") {
                    let timePeriodTags = ["#today", "#thisweek", "#thismonth", "#thisquarter"]
                    let currentTimePeriod = timePeriodTags.first { tag in
                        let allTags = task.tags + TaskItem.extractTags(from: task.notes)
                        return allTags.contains { $0.lowercased() == tag.lowercased() }
                    }
                    
                    Picker("When to do", selection: Binding(
                        get: { currentTimePeriod ?? "" },
                        set: { selectedTag in
                            // Remove existing time period tags
                            var updatedTags = tags.components(separatedBy: " ")
                                .filter { $0.hasPrefix("#") }
                                .map { $0.trimmingCharacters(in: .whitespaces) }
                                .filter { !$0.isEmpty }
                            
                            // Remove all time period tags
                            updatedTags = updatedTags.filter { tag in
                                !timePeriodTags.contains { $0.lowercased() == tag.lowercased() }
                            }
                            
                            // Add selected time period tag if not empty
                            if !selectedTag.isEmpty {
                                updatedTags.append(selectedTag)
                            }
                            
                            tags = updatedTags.joined(separator: " ")
                        }
                    )) {
                        Text("None").tag("")
                        Text("Today").tag("#today")
                        Text("This Week").tag("#thisweek")
                        Text("This Month").tag("#thismonth")
                        Text("This Quarter").tag("#thisquarter")
                    }
                    .pickerStyle(.menu)
                }
                
                Section("Tags") {
                    TextField("Enter tags (e.g., #urgent #important)", text: $tags)
                        .autocapitalization(.none)
                }
                
                // Date and Time section
                Section("Date & Time") {
                    Toggle("Set Due Date", isOn: Binding(
                        get: { hasDueDate },
                        set: { newValue in
                            hasDueDate = newValue
                            if newValue && dueDate == nil {
                                dueDate = Date()
                            }
                        }
                    ))
                    
                    if hasDueDate {
                        DatePicker("Date", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        
                        DatePicker("Time", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: [.hourAndMinute])
                        .datePickerStyle(.compact)
                    } else {
                        Text("No due date set")
                            .foregroundColor(.secondary)
                            .font(.caption)
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
                        // Parse tags from the text field
                        let tagArray = tags.components(separatedBy: " ")
                            .filter { $0.hasPrefix("#") }
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                            .filter { !$0.isEmpty }
                        
                        Task {
                            await remindersManager.updateTask(
                                task,
                                title: title,
                                notes: notes,
                                tags: tagArray,
                                dueDate: hasDueDate ? (dueDate ?? Date()) : nil
                            )
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

struct FullScreenQuadrantView: View {
    let quadrant: Quadrant
    let tasks: [TaskItem]
    let allTasks: [TaskItem]
    @ObservedObject var remindersManager: RemindersManager
    let showOnlyToday: Bool
    let showOnlyThisWeek: Bool
    let onClose: () -> Void
    let onTaskTap: (TaskItem) -> Void
    
    @State private var showingAddTask = false
    @State private var showingEditTask: TaskItem?
    
    private var quadrantColor: Color {
        switch quadrant {
        case .doNow: return Color(red: 1.0, green: 0.4, blue: 0.4) // Lighter red
        case .delegate: return Color(red: 1.0, green: 0.7, blue: 0.3) // Lighter orange
        case .schedule: return Color(red: 0.4, green: 0.6, blue: 1.0) // Lighter blue
        case .bin: return Color(red: 0.6, green: 0.6, blue: 0.6) // Lighter gray
        }
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with close button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quadrant.rawValue)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(quadrantColor)
                        Text(quadrant.description)
                            .font(.subheadline)
                            .foregroundColor(quadrantColor.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Text("\(tasks.count) tasks")
                        .font(.headline)
                        .foregroundColor(quadrantColor)
                    
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(quadrantColor.opacity(0.1))
                
                // Tasks list
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 8) {
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
                                },
                                onSetToday: {
                                    Task {
                                        await remindersManager.setTimePeriodTag(task, tag: "#today")
                                    }
                                },
                                onSetThisWeek: {
                                    Task {
                                        await remindersManager.setTimePeriodTag(task, tag: "#thisweek")
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
                                    onToggleComplete: {},
                                    onSetToday: nil,
                                    onSetThisWeek: nil
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
                            .padding(.vertical, 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                    .foregroundColor(quadrantColor.opacity(0.5))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(quadrant: quadrant, remindersManager: remindersManager)
        }
        .sheet(item: $showingEditTask) { task in
            EditTaskView(task: task, remindersManager: remindersManager)
        }
    }
}

