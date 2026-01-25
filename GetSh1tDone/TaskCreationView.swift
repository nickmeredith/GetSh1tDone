import SwiftUI

struct TaskCreationView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var currentStep: QuestionStep = .enterTask
    @State private var taskDescription: String = ""
    @State private var canDelegate: Bool?
    @State private var selectedDelegate: String?
    @State private var isImportant: Bool?
    @State private var isUrgent: Bool?
    @State private var urgentForYou: Bool?
    @State private var canDelegateUrgent: Bool?
    @State private var needsDate: Bool?
    @State private var taskDate: Date?
    @State private var timePeriod: TimePeriodChoice?
    @State private var reallyNeedsToBeDone: Bool?
    @State private var errorMessage: String?
    @State private var isCreatingTask: Bool = false
    
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
        case complete
    }
    
    enum TimePeriodChoice {
        case today
        case thisWeek
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if currentStep == .enterTask {
                    // Initial screen: Enter task description
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
                            Button("Continue") {
                                currentStep = .canDelegate
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(minWidth: 200, minHeight: 50)
                            .font(.headline)
                        }
                    }
                } else if currentStep == .canDelegate {
                    // Question: Can someone else do this?
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
                } else if currentStep == .selectDelegate {
                    // Select delegate
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
                            Text("Select...").tag(nil as String?)
                            ForEach(remindersManager.delegates, id: \.self) { delegate in
                                Text(delegate).tag(delegate as String?)
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
                } else if currentStep == .isImportant {
                    // Is it Important?
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
                } else if currentStep == .isUrgent {
                    // Is it Urgent?
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
                } else if currentStep == .urgentForYou {
                    // Urgent for you or someone else?
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
                } else if currentStep == .canDelegateUrgent {
                    // Can it be delegated?
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
                                createTask(quadrant: .schedule, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                } else if currentStep == .selectDelegateUrgent {
                    // Select delegate for urgent task
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
                            Text("Select...").tag(nil as String?)
                            ForEach(remindersManager.delegates, id: \.self) { delegate in
                                Text(delegate).tag(delegate as String?)
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
                } else if currentStep == .timePeriod {
                    // Time period for Do Now
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
                                createTask(quadrant: .doNow, tags: ["#today"])
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("This Week") {
                                timePeriod = .thisWeek
                                createTask(quadrant: .doNow, tags: ["#thisweek"])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("Skip") {
                                createTask(quadrant: .doNow, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                } else if currentStep == .needsDate {
                    // Needs date for Schedule
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
                                createTask(quadrant: .schedule, tags: [], dueDate: nil)
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                } else if currentStep == .selectDate {
                    // Select date
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
                        
                        DatePicker("Due Date", selection: Binding(
                            get: { taskDate ?? Date() },
                            set: { taskDate = $0 }
                        ), displayedComponents: [.date])
                        .datePickerStyle(.graphical)
                        .padding()
                        
                        Button("Create Task") {
                            createTask(quadrant: .schedule, tags: [], dueDate: taskDate)
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 80)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    }
                } else if currentStep == .reallyNeedsToBeDone {
                    // Really needs to be done?
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
                                createTask(quadrant: .schedule, tags: [])
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                            
                            Button("No") {
                                reallyNeedsToBeDone = false
                                createTask(quadrant: .bin, tags: [])
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .font(.title3)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal)
                    }
                } else if currentStep == .complete {
                    // Task created
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
                        Button("Cancel") {
                            reset()
                        }
                    }
                }
            }
            .task {
                await remindersManager.loadDelegates()
            }
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
            currentStep = .needsDate
        } else {
            // Important No, Urgent No
            currentStep = .reallyNeedsToBeDone
        }
    }
    
    private func createDelegatedTask() {
        guard let delegate = selectedDelegate else { return }
        let tags = ["#\(delegate)"]
        createTask(quadrant: .delegate, tags: tags)
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
        
        // Build notes with tags included
        var notes = ""
        if !formattedTags.isEmpty {
            notes = formattedTags.joined(separator: " ")
        }
        
        print("🏷️ Creating task with tags: \(formattedTags)")
        
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
                print("❌ Error creating task: \(error)")
            } else {
                print("✅ Task created successfully: \(trimmedDescription)")
                print("📋 Task details - Quadrant: \(quadrant.rawValue), Tags: \(tags), DueDate: \(detectedDate?.description ?? "none")")
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
        
        // Check for day names (Monday, Tuesday, etc.)
        let weekdayNames = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        if let dayName = weekdayNames.first(where: { lowercaseText.contains($0) }),
           let targetWeekday = weekdayNames.firstIndex(of: dayName) {
            let currentWeekday = calendar.component(.weekday, from: now) - 1
            var daysToAdd = targetWeekday - currentWeekday
            if daysToAdd <= 0 {
                daysToAdd += 7
            }
            return calendar.date(byAdding: .day, value: daysToAdd, to: now).map { calendar.startOfDay(for: $0) }
        }
        
        // Check for date patterns (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY)
        let datePattern = #"(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})"#
        if let regex = try? NSRegularExpression(pattern: datePattern, options: .caseInsensitive) {
            let range = NSRange(lowercaseText.startIndex..., in: lowercaseText)
            if let match = regex.firstMatch(in: lowercaseText, options: [], range: range),
               match.numberOfRanges >= 4 {
                let dayRange = Range(match.range(at: 1), in: lowercaseText)!
                let monthRange = Range(match.range(at: 2), in: lowercaseText)!
                let yearRange = Range(match.range(at: 3), in: lowercaseText)!
                
                let day = Int(lowercaseText[dayRange]) ?? 0
                let month = Int(lowercaseText[monthRange]) ?? 0
                var year = Int(lowercaseText[yearRange]) ?? calendar.component(.year, from: now)
                
                // Handle 2-digit years
                if year < 100 {
                    year += 2000
                }
                
                if day > 0 && month > 0 && month <= 12 {
                    var components = DateComponents()
                    components.day = day
                    components.month = month
                    components.year = year
                    if let date = calendar.date(from: components) {
                        return calendar.startOfDay(for: date)
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
        errorMessage = nil
        isCreatingTask = false
    }
}
