import SwiftUI

struct PrioritiesView: View {
    @AppStorage("priorities") private var prioritiesData: Data = Data()
    @State private var priorities: [Priority] = []
    @State private var showingAddPriority = false
    @State private var newPriorityText = ""
    @State private var lastReviewDate: Date?
    
    struct Priority: Identifiable, Codable, Equatable {
        var id = UUID()
        var text: String
        var createdAt: Date
        var lastReviewed: Date?
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Your 5 Priorities")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let lastReview = lastReviewDate {
                        Text("Last reviewed: \(lastReview, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Set your top 5 priorities")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Priorities List
                if priorities.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        Text("No priorities set")
                            .font(.title2)
                        Text("Add your top 5 priorities to help guide your task classification")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                } else {
                    List {
                        ForEach(priorities) { priority in
                            HStack {
                                Text("\(priorities.firstIndex(where: { $0.id == priority.id })! + 1).")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                    .frame(width: 30)
                                
                                Text(priority.text)
                                    .font(.body)
                                
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                        .onDelete(perform: deletePriority)
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if priorities.count < 5 {
                        Button(action: { showingAddPriority = true }) {
                            Label("Add Priority", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    if !priorities.isEmpty {
                        Button(action: reviewPriorities) {
                            Label("Review Priorities", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle("Priorities")
            .sheet(isPresented: $showingAddPriority) {
                AddPriorityView(
                    newPriorityText: $newPriorityText,
                    onSave: {
                        addPriority()
                    }
                )
            }
            .onAppear {
                loadPriorities()
            }
            .onChange(of: priorities) {
                savePriorities()
            }
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

