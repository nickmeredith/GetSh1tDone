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

    private let periods = ["Today", "This Week", "This Month", "This Quarter"]

    var body: some View {
        List {
            Section {
                ForEach(periods, id: \.self) { period in
                    Button {
                        // TODO: wire up per period; dismiss for now
                        dismiss()
                    } label: {
                        HStack {
                            Text(period)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } header: {
                Text("Choose period")
            } footer: {
                Text(mode == .review
                     ? "Review at the end of this period."
                     : "Prepare for the next period.")
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    CoachView()
}
