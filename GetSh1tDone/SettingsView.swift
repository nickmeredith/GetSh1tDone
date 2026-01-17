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
    @State private var newDelegateName = ""
    @State private var editingDelegate: String?
    @State private var editedName = ""
    
    var body: some View {
        Form {
            Section(header: Text("Delegates")) {
                if remindersManager.delegates.isEmpty {
                    Text("No delegates found. Add delegates to manage task assignments.")
                        .foregroundColor(.secondary)
                        .font(.caption)
                } else {
                    ForEach(remindersManager.delegates, id: \.self) { delegate in
                        if editingDelegate == delegate {
                            // Edit mode
                            HStack {
                                TextField("Delegate name", text: $editedName)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Save") {
                                    Task {
                                        await remindersManager.updateDelegate(oldName: delegate, newName: editedName)
                                        editingDelegate = nil
                                        editedName = ""
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Cancel") {
                                    editingDelegate = nil
                                    editedName = ""
                                }
                                .buttonStyle(.bordered)
                            }
                        } else {
                            // Display mode
                            HStack {
                                Text(delegate)
                                    .font(.body)
                                
                                Spacer()
                                
                                Button(action: {
                                    editedName = delegate
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
    @State private var delegateName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Delegate")) {
                    TextField("Delegate name", text: $delegateName)
                        .autocapitalization(.words)
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
                            await remindersManager.addDelegate(delegateName)
                            dismiss()
                        }
                    }
                    .disabled(delegateName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 200)
        #endif
    }
}
