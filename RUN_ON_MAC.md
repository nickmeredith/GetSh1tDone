# How to Run GetSh1tDone on This Mac

**"My Mac" only appears when the macOS scheme is selected.** If you still see only iPhone/iPad simulators, the scheme dropdown is set to the iOS app.

---

## Step 1: Select the macOS scheme

1. In Xcode, look at the **top toolbar** (next to the Run ▶ and Stop ■ buttons).
2. You’ll see a **scheme and destination** control, e.g. **GetSh1tDone** > **iPhone 16** (or similar).
3. **Click the scheme name** (the left part, e.g. **GetSh1tDone**).
4. In the menu, choose **GetSh1tDone macOS** (not “GetSh1tDone”).

---

## Step 2: Choose “My Mac” as destination

1. **Click the destination** (the right part, e.g. **iPhone 16**).
2. In the list you should now see **My Mac** (and possibly “My Mac (Designed for iPad)”).
3. Select **My Mac**.

---

## Step 3: Run

1. Press **⌘R** or click **Run**.
2. When the app asks for **Reminders** access, click **OK**.

---

## If you don’t see “GetSh1tDone macOS” in the scheme list

1. **Product → Scheme → Manage Schemes…**
2. Check that **GetSh1tDone macOS** is in the list.
3. If it’s missing, click **+**, under **Target** choose **GetSh1tDone macOS**, set a name (e.g. **GetSh1tDone macOS**), then **OK**.
4. Ensure the new scheme’s **Shared** checkbox is checked so it’s saved in the project.
5. Close Manage Schemes and pick **GetSh1tDone macOS** from the scheme dropdown again; the destination list should then show **My Mac**.

---

## If “My Mac” still doesn’t appear

- Make sure you really selected **GetSh1tDone macOS** (the scheme), not **GetSh1tDone**. With the iOS scheme, only simulators/devices are shown.
- Try **Product → Destination → Destination Architecture → Show Both** (or **My Mac**) if your Xcode has that menu.
- Quit Xcode, reopen the project, then select **GetSh1tDone macOS** and check the destination list again.
