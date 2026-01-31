import SwiftUI

struct TaskCreationView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var currentStep: QuestionStep = .enterTask
    @State private var taskDescription: String = ""
    @State private var canDelegate: Bool?
    @State private var selectedDelegate: Delegate?
    @State private var isImportant: Bool?
    @State private var isUrgent: Bool?
    @State private var urgentForYou: Bool?
    @State private var canDelegateUrgent: Bool?
    @State private var needsDate: Bool?
    @State private var taskDate: Date?
    @State private var timePeriod: TimePeriodChoice?
    @State private var reallyNeedsToBeDone: Bool?
    @State private var importantForSomeoneElse: Bool?
    @State private var errorMessage: String?
    @State private var isCreatingTask: Bool = false
    @State private var detectedDateFromDescription: Date?
    @State private var showingQuickAddSheet = false
    @State private var quickAddInitialTitle = ""
    /// When Quick Add saves a task, we show the "Task Created!" screen instead of resetting.
    @State private var didSaveFromQuickAdd = false
    
    enum QuestionStep {
        case enterTask
        case canDelegate
        case selectDelegate
        case isImportant
        case isUrgent
        case urgentForYou
        case canDelegateUrgent
        case selectDelegateUrgent
        case needsDate
        case selectDate
        case timePeriod
        case reallyNeedsToBeDone
        case importantForSomeoneElse
        case complete
    }
    
    enum TimePeriodChoice {
        case today
        case thisWeek
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                stepContent
            }
            .navigationTitle("Create Task")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if isCreatingTask {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
            .toolbar {
                if currentStep != .enterTask && currentStep != .complete {
                    ToolbarItem(placement: .cancellationAction) {
                        HStack(spacing: 12) {
                            if let previous = previousStep(for: currentStep) {
                                Button("Back") {
                                    currentStep = previous
                                }
                            }
                            Button("Cancel") {
                                reset()
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingQuickAddSheet) {
                QuickAddFlowView(
                    initialTitle: quickAddInitialTitle,
                    remindersManager: remindersManager,
                    onSaveAndDismiss: {
                        didSaveFromQuickAdd = true
                        currentStep = .complete
                        showingQuickAddSheet = false
                        quickAddInitialTitle = ""
                    },
                    onDismiss: {
                        showingQuickAddSheet = false
                        quickAddInitialTitle = ""
                    }
                )
            }
            .onChange(of: showingQuickAddSheet) { oldValue, newValue in
                if !newValue {
                    if !didSaveFromQuickAdd {
                        reset()
                    }
                    didSaveFromQuickAdd = false
                    quickAddInitialTitle = ""
                }
            }
            .task {
                await remindersManager.loadDelegates()
            }
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .enterTask: enterTaskStep
        case .canDelegate: canDelegateStep
        case .selectDelegate: selectDelegateStep
        case .isImportant: isImportantStep
        case .isUrgent: isUrgentStep
        case .urgentForYou: urgentForYouStep
        case .canDelegateUrgent: canDelegateUrgentStep
        case .selectDelegateUrgent: selectDelegateUrgentStep
        case .timePeriod: timePeriodStep
        case .needsDate: needsDateStep
        case .selectDate: selectDateStep
        case .importantForSomeoneElse: importantForSomeoneElseStep
        case .reallyNeedsToBeDone: reallyNeedsToBeDoneStep
        case .complete: completeStep
        }
    }
    
    private var enterTaskStep: some View {
        VStack(spacing: 20) {
            Text("Please enter the task")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .padding()
            
            TextField("Describe the task", text: $taskDescription, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)
                .padding()
            
            if !taskDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 16) {
                    Button("Continue") {
                        detectedDateFromDescription = detectDate(from: taskDescription)
                        if detectedDateFromDescription != nil {
                            #if DEBUG
                            print("📅 Detected date from description: \(detectedDateFromDescription!)")
                            #endif
                        }
                        currentStep = .canDelegate
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 140, minHeight: 50)
                    .font(.headline)
                    
                    Button("Quick Add") {
                        quickAddInitialTitle = taskDescription
                        showingQuickAddSheet = true
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 140, minHeight: 50)
                    .font(.headline)
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var canDelegateStep: some View {
        VStack(spacing: 20) {
            Text("Can someone else do this?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                canDelegate = true
                                currentStep = .selectDelegate
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                canDelegate = false
                                currentStep = .isImportant
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
    }
    
    private var selectDelegateStep: some View {
        VStack(spacing: 20) {
            Text("Who should do this?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Picker("Delegate", selection: $selectedDelegate) {
                            Text("Select...").tag(nil as Delegate?)
                            ForEach(remindersManager.delegates) { delegate in
                                Text(delegate.displayName).tag(delegate as Delegate?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        
                        if selectedDelegate != nil {
                            Button("Create Task") {
                                createDelegatedTask()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        }
        }
    }
    
    private var isImportantStep: some View {
        VStack(spacing: 20) {
            Text("Is this task Important?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                isImportant = true
                                currentStep = .isUrgent
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                isImportant = false
                                currentStep = .isUrgent
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var isUrgentStep: some View {
        VStack(spacing: 20) {
            Text("Is this task Urgent?\n(I mean really urgent?)")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                isUrgent = true
                                handleUrgentResponse()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                isUrgent = false
                                handleNotUrgentResponse()
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var urgentForYouStep: some View {
        VStack(spacing: 20) {
            Text("Is this urgent for you or someone else?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Text("💡 Tip: Challenge the person - is it really urgent or can it wait?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        VStack(spacing: 16) {
                            Button("For Me") {
                                urgentForYou = true
                                currentStep = .canDelegateUrgent
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("For Someone Else") {
                                urgentForYou = false
                                currentStep = .canDelegateUrgent
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var canDelegateUrgentStep: some View {
        VStack(spacing: 20) {
            Text("Can this be delegated to someone else?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                canDelegateUrgent = true
                                currentStep = .selectDelegateUrgent
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                canDelegateUrgent = false
                                createTask(quadrant: Quadrant.schedule, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var selectDelegateUrgentStep: some View {
        VStack(spacing: 20) {
            Text("Who should do this?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Picker("Delegate", selection: $selectedDelegate) {
                            Text("Select...").tag(nil as Delegate?)
                            ForEach(remindersManager.delegates) { delegate in
                                Text(delegate.displayName).tag(delegate as Delegate?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding()
                        
                        if selectedDelegate != nil {
                            Button("Create Task") {
                                createDelegatedTask()
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .padding(.horizontal)
                        }
        }
    }
    
    private var timePeriodStep: some View {
        VStack(spacing: 20) {
            Text("When does this need to be done?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Today") {
                                timePeriod = .today
                                createTask(quadrant: Quadrant.doNow, tags: ["#today"])
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("This Week") {
                                timePeriod = .thisWeek
                                createTask(quadrant: Quadrant.doNow, tags: ["#thisweek"])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("Skip") {
                                createTask(quadrant: Quadrant.doNow, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var needsDateStep: some View {
        VStack(spacing: 20) {
            Text("Is there a specific date for this?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                needsDate = true
                                currentStep = .selectDate
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                needsDate = false
                                // Use detected date if available, otherwise nil
                                let finalDate = detectedDateFromDescription
                                createTask(quadrant: Quadrant.schedule, tags: [], dueDate: finalDate)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var selectDateStep: some View {
        VStack(spacing: 20) {
            Text("Select the date")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        // Show detected date if available
                        if let detectedDate = detectedDateFromDescription {
                            Text("📅 Detected date: \(formatDate(detectedDate))")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding()
                        }
                        
                        DatePicker("Due Date", selection: Binding(
                            get: { taskDate ?? detectedDateFromDescription ?? Date() },
                            set: { taskDate = $0 }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                        
                        Button("Create Task") {
                            // Use taskDate if set, otherwise use detected date
                            let finalDate = taskDate ?? detectedDateFromDescription
                            createTask(quadrant: Quadrant.schedule, tags: [], dueDate: finalDate)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
        }
    }
    
    private var importantForSomeoneElseStep: some View {
        VStack(spacing: 20) {
            Text("Is this important for someone else?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        Text("💡 Tip: Challenge the person - is it really important versus their other priorities?")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                importantForSomeoneElse = true
                                // Create task with #challenge tag in Bin / Challenge quadrant
                                createTask(quadrant: Quadrant.bin, tags: ["#challenge"])
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                importantForSomeoneElse = false
                                currentStep = .reallyNeedsToBeDone
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var reallyNeedsToBeDoneStep: some View {
        VStack(spacing: 20) {
            Text("Does this really need to be done?")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Show task description
                        if !taskDescription.isEmpty {
                            Text("\"\(taskDescription)\"")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        VStack(spacing: 16) {
                            Button("Yes") {
                                reallyNeedsToBeDone = true
                                createTask(quadrant: Quadrant.schedule, tags: [])
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                reallyNeedsToBeDone = false
                                createTask(quadrant: Quadrant.bin, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
        }
    }
    
    private var completeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            Text("Task Created!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Button("Create Another Task") {
                reset()
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    /// Returns the previous question step for Back navigation, or nil if no back (enterTask or complete).
    private func previousStep(for step: QuestionStep) -> QuestionStep? {
        switch step {
        case .enterTask, .complete: return nil
        case .canDelegate: return .enterTask
        case .selectDelegate: return .canDelegate
        case .isImportant: return .canDelegate
        case .isUrgent: return .isImportant
        case .urgentForYou: return .isUrgent
        case .canDelegateUrgent: return .urgentForYou
        case .selectDelegateUrgent: return .canDelegateUrgent
        case .needsDate: return .isUrgent
        case .selectDate: return .needsDate
        case .timePeriod: return .isUrgent
        case .reallyNeedsToBeDone: return .isUrgent
        case .importantForSomeoneElse: return .isUrgent
        }
    }
    
    private func handleUrgentResponse() {
        if isImportant == true {
            // Important Yes, Urgent Yes → Do Now
            currentStep = .timePeriod
        } else {
            // Important No, Urgent Yes
            currentStep = .urgentForYou
        }
    }
    
    private func handleNotUrgentResponse() {
        if isImportant == true {
            // Important Yes, Urgent No → Schedule
            // If date was already detected, skip the date question
            if detectedDateFromDescription != nil {
                createTask(quadrant: Quadrant.schedule, tags: [], dueDate: detectedDateFromDescription)
            } else {
                currentStep = .needsDate
            }
        } else {
            // Important No, Urgent No → Ask if important for someone else
            currentStep = .importantForSomeoneElse
        }
    }
    
    private func createDelegatedTask() {
        guard let delegate = selectedDelegate else { return }
        let tags = [delegate.hashtag]
        createTask(quadrant: Quadrant.delegate, tags: tags)
    }
    
    private func createTask(quadrant: Quadrant, tags: [String], dueDate: Date? = nil) {
        // Validate task description is not empty
        let trimmedDescription = taskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDescription.isEmpty else {
            errorMessage = "Task description cannot be empty"
            return
        }
        
        // Detect date from task description if not already set
        let detectedDate = dueDate ?? detectDate(from: trimmedDescription)
        
        // Ensure all tags have # prefix and are properly formatted
        let formattedTags = tags.map { tag -> String in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return ""
            }
            // Add # prefix if not present
            if trimmed.hasPrefix("#") {
                return trimmed
            } else {
                return "#\(trimmed)"
            }
        }.filter { !$0.isEmpty }
        
        // Don't put tags in notes here - normalization in addTask will handle that
        // This ensures tags are properly formatted and deduplicated
        let notes = "" // User notes are empty for question-based creation
        
        #if DEBUG
        print("🏷️ Creating task with tags: \(formattedTags)")
        #endif
        
        let task = TaskItem(
            title: trimmedDescription,
            notes: notes,
            quadrant: quadrant,
            tags: formattedTags
        )
        
        isCreatingTask = true
        errorMessage = nil
        
        Task { @MainActor in
            // Clear any previous error
            remindersManager.lastError = nil
            
            await remindersManager.addTask(task, dueDate: detectedDate)
            
            // Wait a moment for the save to complete
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Check if there was an error
            if let error = remindersManager.lastError {
                errorMessage = error
                isCreatingTask = false
                #if DEBUG
                print("❌ Error creating task: \(error)")
                #endif
            } else {
                #if DEBUG
                print("✅ Task created successfully: \(trimmedDescription)")
                #endif
                #if DEBUG
                print("📋 Task details - Quadrant: \(quadrant.rawValue), Tags: \(tags), DueDate: \(detectedDate?.description ?? "none")")
                #endif
                // Small delay to show completion state
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                isCreatingTask = false
                currentStep = .complete
            }
        }
    }
    
    private func detectDate(from text: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let lowercaseText = text.lowercased()
        
        // Check for "today"
        if lowercaseText.contains("today") {
            return calendar.startOfDay(for: now)
        }
        
        // Check for "tomorrow"
        if lowercaseText.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now).map { calendar.startOfDay(for: $0) }
        }
        
        // Check for day names (Monday, Tuesday, etc.) - find next occurrence
        let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for dayName in weekdayNames {
            if lowercaseText.contains(dayName) {
                if let targetWeekday = weekdayNames.firstIndex(of: dayName) {
                    let currentWeekday = calendar.component(.weekday, from: now) - 1
                    var daysToAdd = targetWeekday - currentWeekday
                    // If the day is today or in the past, get next week's occurrence
                    if daysToAdd <= 0 {
                        daysToAdd += 7
                    }
                    if let nextDate = calendar.date(byAdding: .day, value: daysToAdd, to: now) {
                        return calendar.startOfDay(for: nextDate)
                    }
                }
                break // Only process first matching day name
            }
        }
        
        // Check for date patterns (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, MM/DD/YYYY, etc.)
        // Try both DD/MM/YYYY and MM/DD/YYYY formats
        let datePatterns = [
            #"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})"#,  // DD/MM/YYYY or MM/DD/YYYY
            #"(\d{1,2})\s+(\d{1,2})\s+(\d{2,4})"#  // DD MM YYYY
        ]
        
        for datePattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) {
                let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
                if let match = regex.firstMatch(in: lowercaseText, options: [], range: range),
                   match.numberOfRanges >= 4 {
                    let firstRange = Range(match.range(at: 1), in: lowercaseText)!
                    let secondRange = Range(match.range(at: 2), in: lowercaseText)!
                    let yearRange = Range(match.range(at: 3), in: lowercaseText)!
                    
                    let first = Int(lowercaseText[firstRange]) ?? 0
                    let second = Int(lowercaseText[secondRange]) ?? 0
                    var year = Int(lowercaseText[yearRange]) ?? calendar.component(.year, from: now)
                    
                    // Handle 2-digit years
                    if year < 100 {
                        year += 2000
                    }
                    
                    // Try DD/MM/YYYY format first
                    if first > 0 && first <= 31 && second > 0 && second <= 12 {
                        var components = DateComponents()
                        components.day = first
                        components.month = second
                        components.year = year
                        if let date = calendar.date(from: components) {
                            // If date is in the past, use next year
                            if date < now {
                                components.year = year + 1
                                if let nextYearDate = calendar.date(from: components) {
                                    return calendar.startOfDay(for: nextYearDate)
                                }
                            }
                            return calendar.startOfDay(for: date)
                        }
                    }
                    
                    // Try MM/DD/YYYY format if DD/MM didn't work
                    if second > 0 && second <= 31 && first > 0 && first <= 12 {
                        var components = DateComponents()
                        components.day = second
                        components.month = first
                        components.year = year
                        if let date = calendar.date(from: components) {
                            // If date is in the past, use next year
                            if date < now {
                                components.year = year + 1
                                if let nextYearDate = calendar.date(from: components) {
                                    return calendar.startOfDay(for: nextYearDate)
                                }
                            }
                            return calendar.startOfDay(for: date)
                        }
                    }
                }
            }
        }
        
        // Check for month names (e.g., "January 15", "15 January")
        let monthNames = ["january", "february", "march", "april", "may", "june",
                         "july", "august", "september", "october", "november", "december"]
        for (index, monthName) in monthNames.enumerated() {
            if lowercaseText.contains(monthName) {
                // Try to extract day number
                let monthPattern = #"(\d{1,2})\s+"# + monthName + #"|\s+"# + monthName + #"\s+(\d{1,2})"#
                if let regex = try? NSRegularExpression(pattern: monthPattern, options: .caseInsensitive) {
                    let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
                    if let match = regex.firstMatch(in: lowercaseText, options: [], range: range) {
                        var day: Int?
                        if match.numberOfRanges > 1 {
                            let dayRange = Range(match.range(at: 1), in: lowercaseText)
                            if let dayRange = dayRange {
                                day = Int(lowercaseText[dayRange])
                            }
                        }
                        if day == nil && match.numberOfRanges > 2 {
                            let dayRange = Range(match.range(at: 2), in: lowercaseText)
                            if let dayRange = dayRange {
                                day = Int(lowercaseText[dayRange])
                            }
                        }
                        
                        if let day = day, day > 0 && day <= 31 {
                            var components = DateComponents()
                            components.day = day
                            components.month = index + 1
                            components.year = calendar.component(.year, from: now)
                            if let date = calendar.date(from: components) {
                                // If date is in the past, use next year
                                if date < now {
                                    components.year = (components.year ?? 0) + 1
                                    if let nextYearDate = calendar.date(from: components) {
                                        return calendar.startOfDay(for: nextYearDate)
                                    }
                                }
                                return calendar.startOfDay(for: date)
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func reset() {
        currentStep = .enterTask
        taskDescription = ""
        canDelegate = nil
        selectedDelegate = nil
        isImportant = nil
        isUrgent = nil
        urgentForYou = nil
        canDelegateUrgent = nil
        needsDate = nil
        taskDate = nil
        timePeriod = nil
        reallyNeedsToBeDone = nil
        importantForSomeoneElse = nil
        detectedDateFromDescription = nil
        errorMessage = nil
        isCreatingTask = false
    }
}

// MARK: - Quick Add flow: pick quadrant then open Add Task panel
struct QuickAddFlowView: View {
    let initialTitle: String
    @ObservedObject var remindersManager: RemindersManager
    /// Called when user saves a task — close sheet and parent will show "Task Created!" screen.
    var onSaveAndDismiss: () -> Void
    /// Called when user cancels (e.g. from quadrant picker).
    var onDismiss: () -> Void
    
    @State private var selectedQuadrant: Quadrant?
    
    var body: some View {
        quickAddContent
    }
    
    @ViewBuilder
    private var quickAddContent: some View {
        if let quadrant = selectedQuadrant {
            addTaskView(for: quadrant)
        } else {
            quadrantPickerView
        }
    }
    
    private func addTaskView(for quadrant: Quadrant) -> some View {
        return AddTaskView(
            quadrant: quadrant,
            remindersManager: remindersManager,
            initialTitle: initialTitle,
            onSave: { onSaveAndDismiss() }
        )
    }
    
    private var quadrantPickerView: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Which quadrant?")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .padding(.top, 24)
                
                if !initialTitle.isEmpty {
                    Text("\"\(initialTitle)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.horizontal)
                        .lineLimit(2)
                }
                
                quadrantButtons
                    .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    private var quadrantButtons: some View {
        VStack(spacing: 16) {
            ForEach(Quadrant.allCases, id: \.self) { quadrant in
                Button(action: {
                    selectedQuadrant = quadrant
                }) {
                    HStack {
                        Text(quadrant.rawValue)
                            .font(.headline)
                        Text(quadrant.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
