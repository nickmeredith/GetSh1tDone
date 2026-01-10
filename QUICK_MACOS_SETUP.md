# Quick macOS Setup Guide

Your code is now platform-agnostic! Here's the fastest way to get it running on macOS:

## Step-by-Step Setup (5 minutes)

### 1. Create New macOS Project

1. Open **Xcode**
2. **File → New → Project** (or Cmd+Shift+N)
3. Select **"macOS"** tab → **"App"**
4. Click **Next**
5. Fill in:
   - **Product Name**: `GetSh1tDone`
   - **Team**: Your team
   - **Organization Identifier**: `com.yourname` (or your existing one)
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Storage**: **None** (we'll add files manually)
6. Choose a location (can be same folder or different)
7. Click **Create**

### 2. Add Existing Source Files

1. In Xcode, **delete** the default files:
   - Right-click `ContentView.swift` → Delete → Move to Trash
   - Right-click `GetSh1tDoneApp.swift` → Delete → Move to Trash

2. **Add your source files:**
   - Right-click the `GetSh1tDone` folder (blue icon)
   - Select **"Add Files to GetSh1tDone..."**
   - Navigate to: `GetSh1tDone/GetSh1tDone/` folder
   - Select **ALL** these files:
     - ✅ GetSh1tDoneApp.swift
     - ✅ ContentView.swift
     - ✅ RemindersManager.swift
     - ✅ EisenhowerMatrixView.swift
     - ✅ TaskQuadrant.swift
     - ✅ PlanningView.swift
     - ✅ TaskChallengeView.swift
     - ✅ PrioritiesView.swift
   - **IMPORTANT**: Uncheck **"Copy items if needed"** (files are already in place)
   - Make sure **"Add to targets: GetSh1tDone"** is checked
   - Click **Add**

3. **Add Assets:**
   - Same process: Right-click → Add Files
   - Select `Assets.xcassets` folder
   - Uncheck "Copy items if needed"
   - Click **Add**

### 3. Configure Project Settings

1. **Select the project** (blue icon) in navigator
2. **Select the target** "GetSh1tDone" under TARGETS
3. **General Tab:**
   - **Minimum Deployments**: macOS 14.0 (or 13.0 if you prefer)
   - **Bundle Identifier**: `com.yourname.getsh1tdone` (or your preference)

4. **Info Tab:**
   - Click **"+"** to add new key
   - Key: `NSRemindersUsageDescription`
   - Type: **String**
   - Value: `GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.`

5. **Signing & Capabilities Tab:**
   - Check **"Automatically manage signing"**
   - Select your **Team**
   - Click **"+ Capability"**
   - Add **"App Sandbox"**
   - In App Sandbox, check **"Calendars"** (Read/Write)

### 4. Build and Run!

1. Select **"My Mac"** as the run destination (top toolbar)
2. Click **Run** (or press Cmd+R)
3. Grant Reminders access when prompted
4. Your app should launch on macOS! 🎉

## What Works on macOS

✅ All features work the same:
- Eisenhower Matrix view
- Drag and drop between quadrants
- Add/Edit/Delete tasks
- Planning assistant
- Task challenges
- Priorities management
- Full sync with Apple Reminders
- iCloud sync

## Differences on macOS

- **Haptic feedback**: Uses system beep instead (macOS doesn't have haptics)
- **Window size**: Appears in a resizable window
- **Keyboard shortcuts**: Standard macOS shortcuts work

## Troubleshooting

**If reminders don't sync:**
- Check System Settings → Privacy & Security → Calendars
- Ensure GetSh1tDone has access
- Check that Reminders app is signed into iCloud

**If build fails:**
- Make sure all Swift files are added to the target
- Check that Assets.xcassets is included
- Verify minimum deployment is macOS 13.0 or later

That's it! Your app now works on both iOS and macOS! 🚀


