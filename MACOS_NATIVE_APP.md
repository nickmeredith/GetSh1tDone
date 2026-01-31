# Run GetSh1tDone on Mac as a Native App

The app is written in **SwiftUI** and already uses `#if os(iOS)` / `#if os(macOS)` where needed (PrioritiesView, EisenhowerMatrixView, SettingsView). The project now includes a **macOS target** so you can run it on Mac from the same codebase.

---

## Steps already done (in the project)

- **macOS target** “GetSh1tDone macOS” added to the Xcode project.
- **Same source files** are built for the macOS target (all app Swift files + Assets.xcassets).
- **macOS build settings:** SDKROOT = macosx, MACOSX_DEPLOYMENT_TARGET = 14.0, PRODUCT_BUNDLE_IDENTIFIER = com.getsh1tdone.app.macos, NSRemindersUsageDescription set.
- **Entitlements:** App Sandbox + Calendars (Read/Write) in GetSh1tDone.entitlements for Reminders access.
- **Shared scheme** “GetSh1tDone macOS” in `xcshareddata/xcschemes` so you can select and run the Mac app.

**What you do:** Open the project in Xcode → choose scheme **GetSh1tDone macOS** → destination **My Mac** → **Product → Run** (⌘R). Grant Reminders access when prompted.

---

## Troubleshooting: “My Mac” is not in the destination

If you don’t see **My Mac** in the run-destination dropdown:

1. **Switch to the macOS scheme**  
   The destination list is tied to the **selected scheme**. If the scheme is **GetSh1tDone** (iOS), you only get iOS destinations (simulators, “Any iOS Device”)—**My Mac** will not appear.  
   - In the Xcode toolbar, click the **scheme** dropdown (it shows the current scheme, e.g. “GetSh1tDone”).  
   - Choose **GetSh1tDone macOS**.  
   - The **destination** dropdown should now show **My Mac** (and any other Mac run destinations).

2. **If “GetSh1tDone macOS” is not in the scheme list**  
   - Quit Xcode, reopen **GetSh1tDone.xcodeproj**, and check the scheme dropdown again.  
   - The shared scheme lives in `GetSh1tDone.xcodeproj/xcshareddata/xcschemes/GetSh1tDone macOS.xcscheme`; if that file is present, the scheme should appear.

3. **Clean and reopen**  
   After project/scheme changes, sometimes Xcode needs a refresh: **Product → Clean Build Folder** (⇧⌘K), then quit Xcode and reopen the project. Then select **GetSh1tDone macOS** and check the destination list again.

---

## Reference: Add a macOS Target (already done)

One codebase, one repo, two apps: **GetSh1tDone** (iOS) and **GetSh1tDone** (macOS).

### 1. Add the macOS target in Xcode

1. Open **GetSh1tDone.xcodeproj** in Xcode.
2. **File → New → Target…**
3. Select **macOS** tab → **App** → Next.
4. Set:
   - **Product Name:** `GetSh1tDone macOS` (or `GetSh1tDone`)
   - **Team:** same as iOS
   - **Organization Identifier:** same as iOS (e.g. `com.yourname`)
   - **Interface:** SwiftUI  
   - **Language:** Swift  
   - **Storage:** None  
5. Click **Finish**.  
   If asked “Activate ‘GetSh1tDone macOS’ scheme?”, click **Activate** (you can switch schemes later).

### 2. Use the same source files for the macOS target

1. In the **Project Navigator**, select all your app Swift files under the GetSh1tDone group (e.g. GetSh1tDoneApp.swift, ContentView.swift, RemindersManager.swift, Delegate.swift, EisenhowerMatrixView.swift, SettingsView.swift, TaskQuadrant.swift, CoachView.swift, TaskChallengeView.swift, PrioritiesView.swift, TaskCreationView.swift).
2. In the **File Inspector** (right panel), under **Target Membership** check **both**:
   - **GetSh1tDone** (iOS)
   - **GetSh1tDone macOS** (macOS)
3. Add **Assets.xcassets** to the macOS target the same way: select it → File Inspector → check **GetSh1tDone macOS**.

### 3. Point the macOS app at the same `@main` and ContentView

- The macOS target will compile the same **GetSh1tDoneApp.swift** and **ContentView.swift**, so it will launch the same UI. You only have one `@main` in the project; that’s correct.
- If Xcode created a second **GetSh1tDoneApp.swift** (or similar) inside a “GetSh1tDone macOS” folder, **remove** that file from the macOS target (or delete it and keep using the shared app file) so only the shared `GetSh1tDoneApp` is the app entry point.

### 4. macOS target settings

1. Select the **project** (blue icon) → select the **GetSh1tDone macOS** target.
2. **General**
   - **Minimum Deployments:** macOS 14.0 (to match EventKit/Reminders APIs you use).
   - **Bundle Identifier:** e.g. `com.yourname.getsh1tdone.macos` (must differ from the iOS app if you want both on the same machine).
3. **Signing & Capabilities**
   - Enable **App Sandbox**.
   - Under App Sandbox, enable **Calendars** (Read/Write) for Reminders.
4. **Info** (or Info.plist for the macOS target)
   - Add **NSRemindersUsageDescription** (string):  
     `GetSh1tDone needs access to your reminders to help you organize tasks in the Eisenhower matrix.`

### 5. macOS entitlements (if needed)

- If the target has an entitlements file, it should include App Sandbox and Calendars. If you use a custom entitlements file, ensure **Calendars** is allowed there too.

### 6. Build and run on Mac

1. In the scheme selector (top toolbar), choose **GetSh1tDone macOS** (or the name you gave the macOS target).
2. Select destination **My Mac**.
3. **Product → Run** (or ⌘R).
4. Grant Reminders access when the app prompts.

You now have a **native macOS app** that shares all logic and UI with the iOS app; only the platform-specific bits (e.g. haptics, window sizing) are already handled with `#if os(macOS)`.

---

## Alternative: New macOS-only project

If you prefer a **separate** Mac app project:

1. **File → New → Project** → macOS → App (SwiftUI, Swift).
2. Delete the default Swift files Xcode creates.
3. **Add Files to “…”** and add your existing GetSh1tDone Swift files and Assets **without** copying (reference the same folder).
4. Configure the new target’s Info.plist (NSRemindersUsageDescription), App Sandbox, and Calendars as above.

Downside: two projects to maintain; any change must be made in both (or you need a shared package/framework). The **single project with an extra macOS target** is usually simpler.

---

## Summary

| Approach | Pros | Cons |
|----------|------|------|
| **Add macOS target** (recommended) | One repo, one codebase, shared sources | One-time target/settings setup |
| New macOS project | Fully separate Mac app | Duplicate code or extra setup for sharing |
| Catalyst (iOS app on Mac) | No second target | Less “native” Mac feel; often more quirks |

**Best way to replicate this app to run on a Mac as a native application:** add a **macOS target** to the existing Xcode project and include the same Swift files and assets in that target, then configure signing, sandbox, and Reminders usage. You already have the right `#if os(macOS)` in place; the rest is project configuration.
