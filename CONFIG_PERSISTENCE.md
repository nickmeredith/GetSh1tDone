# Persisting configuration settings (non-Reminders)

Settings that don’t live in Reminders (Coach schedules, priorities list, last review date, etc.) need to be stored on device. This doc recommends one consistent approach and when to use alternatives.

---

## Recommended: UserDefaults + Codable

**Use UserDefaults** for:

- Small, preference-style config (toggles, frequencies, schedules)
- Data that fits in a few dozen keys and modest payloads (e.g. JSON-encoded structs)

**Why it fits this app:**

- Backed up with the app (and iCloud backup) by default
- No extra frameworks; works on iOS and macOS
- Fast and simple for read/write
- Fits the amount of config you have (Coach config, priorities list, last review date)

**Pattern used in the project:**

1. **Centralize keys** – Define all UserDefaults keys in one place (e.g. `CoachConfigKeys` / `AppConfigKeys`) so there are no magic strings and new settings are easy to add.
2. **Use Codable + JSON for structs** – Encode/decode config types (e.g. `ReviewPrepareConfig`, `FrequencyConfig`) with `JSONEncoder` / `JSONDecoder` and store the `Data` in UserDefaults. Use a default value when load fails (e.g. first launch or corrupt data).
3. **Dedicated load/save helpers** – A small storage type (e.g. `CoachConfigStorage`) per area keeps persistence logic in one place and keeps views thin.

Example (conceptually):

```swift
// Keys in one place
private enum CoachConfigKeys {
    static let review = "coachReviewConfig"
    // ...
}

// Load: decode or default
static func loadReview() -> ReviewPrepareConfig {
    guard let data = UserDefaults.standard.data(forKey: CoachConfigKeys.review),
          let decoded = try? JSONDecoder().decode(ReviewPrepareConfig.self, from: data) else {
        return .default
    }
    return decoded
}

// Save: encode and set
static func saveReview(_ config: ReviewPrepareConfig) {
    if let data = try? JSONEncoder().encode(config) {
        UserDefaults.standard.set(data, forKey: CoachConfigKeys.review)
    }
}
```

For simple values (e.g. a single date), you can use `UserDefaults.standard.set(_:forKey:)` / `object(forKey:)` with the same central key constant.

---

## Optional: App Group (iOS + macOS)

If you add an **App Group** so the iOS and macOS targets share data:

1. Enable the App Group capability for both targets (same group id, e.g. `group.com.getsh1tdone.app`).
2. Use a shared UserDefaults instead of `UserDefaults.standard`:

   ```swift
   let store = UserDefaults(suiteName: "group.com.getsh1tdone.app") ?? .standard
   store.set(data, forKey: key)
   ```

Then config persisted in that suite is visible to both apps. Without this, iOS and macOS each have their own UserDefaults.

---

## When to use something else

| Need | Option |
|------|--------|
| **Sync config across user’s devices** | `NSUbiquitousKeyValueStore` (iCloud key-value) or CloudKit. More setup; use only if you need cross-device sync. |
| **Large or complex config / export** | Write a JSON (or plist) file under `FileManager.default.urls(for: .applicationSupportDirectory, ...)` and load/save that file. |
| **Secrets (tokens, passwords)** | Keychain (e.g. `Security` framework or a small Keychain wrapper). Do not use UserDefaults for secrets. |

For the current Coach and priorities config, **UserDefaults + central keys + Codable** is a good and sufficient way to persist settings that aren’t stored in Reminders.
