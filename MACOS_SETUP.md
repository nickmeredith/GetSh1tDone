# Making GetSh1tDone Work on macOS

The app code is already platform-agnostic, but the Xcode project needs to be configured for macOS. Here are two options:

## Option 1: Create a New macOS Project (Recommended)

1. **Open Xcode**
2. **File → New → Project**
3. Choose **"macOS"** → **"App"**
4. Product Name: `GetSh1tDone`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Save location: Choose a different folder (e.g., `GetSh1tDone-macOS`)
8. Click **Create**

9. **Add the source files:**
   - Delete the default ContentView.swift and App file that Xcode created
   - Right-click on the GetSh1tDone folder in the project navigator
   - Select **"Add Files to GetSh1tDone..."**
   - Navigate to the `GetSh1tDone/GetSh1tDone` folder and select ALL the .swift files:
     - GetSh1tDoneApp.swift
     - ContentView.swift
     - RemindersManager.swift
     - EisenhowerMatrixView.swift
     - TaskQuadrant.swift
     - PlanningView.swift
     - TaskChallengeView.swift
     - PrioritiesView.swift
   - Make sure **"Copy items if needed"** is UNCHECKED
   - Click **"Add"**

10. **Add Assets:**
    - Add the Assets.xcassets folder the same way

11. **Configure Info.plist:**
    - Select the project → Target → **"Info"** tab
    - Add key: `NSRemindersUsageDescription`
    - Value: `GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.`

12. **Add Entitlements:**
    - Select the project → Target → **"Signing & Capabilities"**
    - Click **"+ Capability"** → Add **"App Sandbox"**
    - In App Sandbox, enable **"Calendars"** (Read/Write)

13. **Build and Run!**

## Option 2: Add macOS Target to Existing Project

1. **Open the existing project** in Xcode
2. **File → New → Target**
3. Choose **"macOS"** → **"App"**
4. Product Name: `GetSh1tDone-macOS`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Click **Finish**

8. **Share source files:**
    - Select the new macOS target
    - Go to **"Build Phases"** → **"Compile Sources"**
    - Add all the Swift files from the iOS target
    - Or better: Select each Swift file, open File Inspector, and check both targets

9. **Configure the macOS target:**
    - Add the same Info.plist entries
    - Add App Sandbox capability with Calendars access

## Option 3: Use the Updated Project Generator

I'll update the project generator script to create a multiplatform project that works on both iOS and macOS.


