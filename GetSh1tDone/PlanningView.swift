import SwiftUI

enum PlanningPeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case fortnight = "Fortnight"
}

struct PlanningView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var selectedPeriod: PlanningPeriod = .day
    @State private var currentQuestionIndex = 0
    @State private var answers: [String: String] = [:]
    @State private var showingMatrix = false
    
    private var questions: [String] {
        switch selectedPeriod {
        case .day:
            return [
                "What are the most urgent tasks that must be done today?",
                "What important tasks will move you toward your goals today?",
                "What tasks can you delegate or ask for help with?",
                "What tasks are not urgent and can be scheduled for later?",
                "What tasks should be eliminated or removed from your list?"
            ]
        case .week:
            return [
                "What are your top 3 priorities for this week?",
                "What urgent deadlines are coming up this week?",
                "What important projects need progress this week?",
                "What tasks can be delegated this week?",
                "What can be scheduled for next week or later?"
            ]
        case .fortnight:
            return [
                "What are your major goals for the next two weeks?",
                "What important projects need to be started or advanced?",
                "What urgent items need attention in the next two weeks?",
                "What can be delegated or outsourced?",
                "What should be removed from your list entirely?"
            ]
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Period Selection
                Picker("Planning Period", selection: $selectedPeriod) {
                    ForEach(PlanningPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                if currentQuestionIndex < questions.count {
                    // Question View
                    VStack(spacing: 20) {
                        Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(questions[currentQuestionIndex])
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        TextEditor(text: Binding(
                            get: { answers[questions[currentQuestionIndex]] ?? "" },
                            set: { answers[questions[currentQuestionIndex]] = $0 }
                        ))
                        .frame(height: 200)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                        
                        HStack {
                            if currentQuestionIndex > 0 {
                                Button("Previous") {
                                    withAnimation {
                                        currentQuestionIndex -= 1
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Button(currentQuestionIndex == questions.count - 1 ? "Finish" : "Next") {
                                withAnimation {
                                    if currentQuestionIndex < questions.count - 1 {
                                        currentQuestionIndex += 1
                                    } else {
                                        showingMatrix = true
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    }
                    .padding()
                } else {
                    // Summary View
                    VStack(spacing: 20) {
                        Text("Planning Complete!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Review your answers and organize your tasks in the matrix.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        
                        Button("View Matrix") {
                            showingMatrix = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
            .navigationTitle("Plan Your \(selectedPeriod.rawValue)")
            .sheet(isPresented: $showingMatrix) {
                EisenhowerMatrixView()
                    .environmentObject(remindersManager)
            }
        }
    }
}

