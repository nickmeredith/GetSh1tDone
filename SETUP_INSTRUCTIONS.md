# Setup Instructions for GetSh1tDone

Since the Xcode project file may have issues, here's how to create it properly:

## Option 1: Create New Project in Xcode (Recommended)

1. Open Xcode
2. File → New → Project
3. Choose "macOS" → "App"
4. Product Name: `GetSh1tDone`
5. Interface: SwiftUI
6. Language: Swift
7. Save location: Choose the parent folder (IOS_Projects)
8. Click Create

9. **Add the source files:**
   - Delete the default ContentView.swift and App file that Xcode created
   - Right-click on the GetSh1tDone folder in the project navigator
   - Select "Add Files to GetSh1tDone..."
   - Navigate to the GetSh1tDone folder and select ALL the .swift files:
     - GetSh1tDoneApp.swift
     - ContentView.swift
     - RemindersManager.swift
     - EisenhowerMatrixView.swift
     - TaskQuadrant.swift
     - PlanningView.swift
     - TaskChallengeView.swift
     - PrioritiesView.swift
   - Make sure "Copy items if needed" is UNCHECKED (files are already in place)
   - Click "Add"

10. **Add Assets:**
   - Add the Assets.xcassets folder the same way

11. **Configure Info.plist:**
   - Select the project in the navigator
   - Go to the "Info" tab
   - Add a new key: `NSRemindersUsageDescription`
   - Value: `GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.`

12. **Add Entitlements:**
   - Select the project → Target → "Signing & Capabilities"
   - Click "+ Capability" → Add "App Sandbox"
   - In App Sandbox, enable "User Selected File" (Read/Write)

13. **Build and Run!**

## Option 2: Use the provided script

Run the setup script if available.


