import SwiftUI

/// Coach: Review, Prepare, Priorities, Goals, Clean up. Review/Prepare lead to period choice (Today, This Week, etc.).
struct CoachView: View {
    var body: some View {
        NavigationStack {
            List {
                // Review → then choose Today / This Week / This Month / This Quarter
                NavigationLink {
                    CoachPeriodChoiceView(mode: .review)
                } label: {
                    Label("Review", systemImage: "arrow.clockwise.circle.fill")
                }

                // Prepare → then choose Today / This Week / This Month / This Quarter
                NavigationLink {
                    CoachPeriodChoiceView(mode: .prepare)
                } label: {
                    Label("Prepare", systemImage: "forward.circle.fill")
                }

                // Priorities (instructions later)
                Button {
                    // TODO: instructions later
                } label: {
                    Label("Priorities", systemImage: "star.circle.fill")
                        .foregroundColor(.primary)
                }

                // Goals (instructions later)
                Button {
                    // TODO: instructions later
                } label: {
                    Label("Goals", systemImage: "target")
                        .foregroundColor(.primary)
                }

                // Clean up
                Button {
                    // TODO: instructions later
                } label: {
                    Label("Clean up", systemImage: "trash.circle.fill")
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Review vs Prepare mode
enum CoachPeriodMode {
    case review
    case prepare
}

// MARK: - Period choice (Today, This Week, This Month, This Quarter)
struct CoachPeriodChoiceView: View {
    let mode: CoachPeriodMode
    @Environment(\.dismiss) private var dismiss

    private var title: String {
        switch mode {
        case .review: return "Review"
        case .prepare: return "Prepare"
        }
    }

    var body: some View {
        List {
            Section {
                switch mode {
                case .review:
                    ForEach(PreparePeriod.allCases, id: \.id) { period in
                        Button {
                            // TODO: Review flow per period
                            dismiss()
                        } label: {
                            periodRow(period.rawValue)
                        }
                    }
                case .prepare:
                    ForEach(PreparePeriod.allCases, id: \.id) { period in
                        NavigationLink {
                            PrepareQuestionsView(period: period) {
                                dismiss()
                            }
                        } label: {
                            Text(period.rawValue)
                        }
                    }
                }
            } header: {
                Text("Choose period")
            } footer: {
                Text(mode == .review
                     ? "Review at the end of this period."
                     : "Prepare for the next period. Each answer is added as a reminder in the matching list (today, this week, this month, this quarter) with title starting with Prepare-.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func periodRow(_ label: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Prepare questions form and commit plans
struct PrepareQuestionsView: View {
    let period: PreparePeriod
    /// Called after reminders are added so we can dismiss back to main Coach (e.g. parent dismisses too).
    var onSuccessDismissToRoot: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var answers: [String] = []
    @State private var isWriting = false
    @State private var errorMessage: String?
    @State private var didWrite = false

    init(period: PreparePeriod, onSuccessDismissToRoot: (() -> Void)? = nil) {
        self.period = period
        self.onSuccessDismissToRoot = onSuccessDismissToRoot
        _answers = State(initialValue: Array(repeating: "", count: period.questions.count))
    }

    private var canSubmit: Bool {
        answers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var successButtonLabel: String {
        didWrite ? "Plans committed" : "Commit these plans"
    }

    var body: some View {
        Form {
            Section {
                Text(period.sectionTitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ForEach(Array(period.questions.enumerated()), id: \.offset) { index, question in
                Section {
                    #if os(iOS)
                    TextField("Your answer", text: $answers[index], axis: .vertical)
                        .lineLimit(3...8)
                    #else
                    TextField("Your answer", text: $answers[index])
                    #endif
                } header: {
                    Text(question)
                }
            }

            if let err = errorMessage {
                Section {
                    Text(err)
                        .foregroundColor(.red)
                }
            }

            Section {
                Button {
                    submitToReminders()
                } label: {
                    HStack {
                        if isWriting {
                            ProgressView()
                                .scaleEffect(0.9)
                        }
                        Text(successButtonLabel)
                    }
                }
                .disabled(!canSubmit || isWriting)
            } footer: {
                Text("Each answer is added as a reminder in the \"\(period.reminderListName)\" list with title starting with Prepare- . Create reminder lists named today, this week, this month, and this quarter if needed.")
            }
        }
        .navigationTitle(period.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if answers.count != period.questions.count {
                answers = Array(repeating: "", count: period.questions.count)
            }
            if period == .day {
                Task { @MainActor in
                    let prefill = await remindersManager.prepareSessionForToday(listName: period.reminderListName)
                    if !prefill.isEmpty {
                        var newAnswers = Array(repeating: "", count: period.questions.count)
                        for (i, pair) in prefill.enumerated() where i < newAnswers.count {
                            newAnswers[i] = pair.answer
                        }
                        answers = newAnswers
                    }
                }
            }
        }
    }

    private func submitToReminders() {
        errorMessage = nil
        isWriting = true
        let result = PrepareResult(
            period: period,
            writtenAt: Date(),
            answers: Array(zip(period.questions, answers))
        )
        Task { @MainActor in
            do {
                try await remindersManager.addPrepareReminders(listName: result.period.reminderListName, questionAnswerPairs: result.answers)
                didWrite = true
                dismiss()
                onSuccessDismissToRoot?()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
            isWriting = false
        }
    }
}

#Preview {
    CoachView()
}
