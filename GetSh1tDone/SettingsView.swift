import SwiftUI

struct SettingsView: View {
    @ObservedObject var remindersManager: RemindersManager
    
    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: DelegatesSettingsView(remindersManager: remindersManager)) {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        Text("Delegates")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct DelegatesSettingsView: View {
    @ObservedObject var remindersManager: RemindersManager
    @State private var showingAddDelegate = false
    @State private var editingDelegate: Delegate?
    @State private var editedShortName = ""
    @State private var editedFullName = ""
    
    var body: some View {
        Form {
            Section(header: Text("Delegates")) {
                if remindersManager.delegates.isEmpty {
                    Text("No delegates found. Add delegates to manage task assignments.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(remindersManager.delegates) { delegate in
                        if editingDelegate?.id == delegate.id {
                            // Edit mode
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Short Name (for hashtag)", text: $editedShortName)
                                    .textFieldStyle(.roundedBorder)
                                    .autocapitalization(.none)
                                
                                TextField("Full Name (optional)", text: $editedFullName)
                                    .textFieldStyle(.roundedBorder)
                                
                                HStack {
                                    Button("Save") {
                                        Task {
                                            await remindersManager.updateDelegate(delegate, newShortName: editedShortName, newFullName: editedFullName)
                                            editingDelegate = nil
                                            editedShortName = ""
                                            editedFullName = ""
                                        }
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Cancel") {
                                        editingDelegate = nil
                                        editedShortName = ""
                                        editedFullName = ""
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            // Display mode
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(delegate.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Text("Tag: \(delegate.hashtag)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    editedShortName = delegate.shortName
                                    editedFullName = delegate.fullName
                                    editingDelegate = delegate
                                }) {
                                    Image(systemName: "pencil")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                Button(role: .destructive, action: {
                                    Task {
                                        await remindersManager.removeDelegate(delegate)
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                Button(action: {
                    showingAddDelegate = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Delegate")
                    }
                }
            }
        }
        .navigationTitle("Delegates")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddDelegate) {
            AddDelegateView(remindersManager: remindersManager)
        }
        .task {
            await remindersManager.loadDelegates()
        }
    }
}

struct AddDelegateView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var remindersManager: RemindersManager
    @State private var shortName = ""
    @State private var fullName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Delegate")) {
                    TextField("Short Name (for hashtag)", text: $shortName)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                    
                    TextField("Full Name (optional)", text: $fullName)
                        .autocapitalization(.words)
                }
                
                Section(footer: Text("Short name is used for the hashtag (e.g., #JohnD). Full name is displayed in the delegate list.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Delegate")
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
                            await remindersManager.addDelegate(shortName: shortName, fullName: fullName)
                            dismiss()
                        }
                    }
                    .disabled(shortName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 250)
        #endif
    }
}
