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
            
            PlanningView(remindersManager: remindersManager)
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(1)
            
            PrioritiesView()
                .environmentObject(remindersManager)
                .tabItem {
                    Label("Plan", systemImage: "calendar")
                }
                .tag(2)
            
            TaskChallengeView(remindersManager: remindersManager)
                .tabItem {
                    Label("Challenges", systemImage: "lightbulb")
                }
                .tag(3)
        }
    }
}

