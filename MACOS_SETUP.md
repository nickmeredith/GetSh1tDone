# Making GetSh1tDone Work on macOS

The app code is already set up for both iOS and macOS (`#if os(iOS)` / `#if os(macOS)` in PrioritiesView, EisenhowerMatrixView, SettingsView). The Xcode project just needs a macOS target.

**→ For the recommended steps, see [MACOS_NATIVE_APP.md](MACOS_NATIVE_APP.md).** It describes adding a macOS target to the existing project so one codebase builds both iOS and Mac apps.

## Quick summary

- **Best approach:** Add a **macOS target** to the existing project (File → New → Target → macOS → App), then include the same Swift files and Assets in that target. Configure App Sandbox + Calendars and `NSRemindersUsageDescription`.
- **Source files to include** in the macOS target: GetSh1tDoneApp.swift, ContentView.swift, RemindersManager.swift, Delegate.swift, EisenhowerMatrixView.swift, SettingsView.swift, TaskQuadrant.swift, CoachView.swift, TaskChallengeView.swift, PrioritiesView.swift, TaskCreationView.swift, plus Assets.xcassets.
- **Alternative:** Create a new macOS-only project and add these files by reference (see [MACOS_NATIVE_APP.md](MACOS_NATIVE_APP.md)).


