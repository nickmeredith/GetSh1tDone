import SwiftUI

struct ContentView: View {
    @StateObject private var remindersManager = RemindersManager()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EisenhowerMatrixView()
                .environmentObject(remindersManager)
                .tabItem {
                    Label("Matrix", systemImage: "square.grid.2x2")
                }
                .tag(0)
            
            CoachView()
                .environmentObject(remindersManager)
                .tabItem {
                    Label("Coach", systemImage: "person.crop.circle.fill")
                }
                .tag(1)
            
            PrioritiesView()
                .environmentObject(remindersManager)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(2)
            
            TaskCreationView(remindersManager: remindersManager)
                .tabItem {
                    Label("Task", systemImage: "plus.circle.fill")
                }
                .tag(3)
            
            SettingsView(remindersManager: remindersManager)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
    }
}

