import SwiftUI

struct TaskChallengeView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var challengeType: ChallengeType = .clarity
    @State private var currentTaskIndex = 0
    @State private var showingTaskDetail: TaskItem?
    
    enum ChallengeType: String, CaseIterable {
        case clarity = "Clarity"
        case delegation = "Delegation"
        case smart = "SMART Goals"
        case relevance = "Relevance"
    }
    
    private var tasksToReview: [TaskItem] {
        switch challengeType {
        case .clarity:
            return remindersManager.tasks.filter { task in
                task.title.count < 10 || task.title.lowercased().contains("thing") || 
                task.title.lowercased().contains("stuff")
            }
        case .delegation:
            return remindersManager.tasks.filter { $0.quadrant != .delegate }
        case .smart:
            return remindersManager.tasks.filter { !$0.isCompleted }
        case .relevance:
            return remindersManager.getOldTasks(daysOld: 7)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Challenge Type Selection
                Picker("Challenge Type", selection: $challengeType) {
                    ForEach(ChallengeType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if tasksToReview.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("All tasks reviewed!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("No tasks need attention for this challenge type.")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if currentTaskIndex < tasksToReview.count {
                    let task = tasksToReview[currentTaskIndex]
                    
                    VStack(spacing: 20) {
                        Text("Task \(currentTaskIndex + 1) of \(tasksToReview.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Challenge Question
                        Text(challengeQuestion)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        // Task Card
                        VStack(alignment: .leading, spacing: 12) {
                            Text(task.title)
                                .font(.headline)
                            
                            if !task.notes.isEmpty {
                                Text(task.notes)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("Quadrant: \(task.quadrant.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        .onTapGesture {
                            showingTaskDetail = task
                        }
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button("Skip") {
                                withAnimation {
                                    if currentTaskIndex < tasksToReview.count - 1 {
                                        currentTaskIndex += 1
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button("Edit Task") {
                                showingTaskDetail = task
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Next") {
                                withAnimation {
                                    if currentTaskIndex < tasksToReview.count - 1 {
                                        currentTaskIndex += 1
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        Text("Challenge Complete!")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding()
                }
            }
            .navigationTitle("Task Challenges")
            .sheet(item: $showingTaskDetail) { task in
                TaskDetailView(task: task, remindersManager: remindersManager)
            }
            .task {
                await remindersManager.loadReminders()
            }
        }
    }
    
    private var challengeQuestion: String {
        switch challengeType {
        case .clarity:
            return "Is this task clear and specific? Can you make it more actionable?"
        case .delegation:
            return "Can this task be delegated to someone else? Should it be moved to 'Delegate'?"
        case .smart:
            return "Is this task SMART (Specific, Measurable, Achievable, Relevant, Time-bound)?"
        case .relevance:
            return "This task hasn't been touched in a while. Is it still relevant? Should it be removed?"
        }
    }
}

