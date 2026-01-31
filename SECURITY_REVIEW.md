# Security Review: GetSh1tDone

**Scope:** GetSh1tDone iOS/macOS app (Apple Reminders, Eisenhower matrix, Coach, Plan).  
**Guidelines:** OWASP Mobile Top 10, OWASP MASVS (Mobile Application Security Verification Standard), and general secure coding practices.

---

## Executive Summary

The app has **no network access**, uses **system APIs (EventKit)** for reminders with proper permission flow, and **no eval/dynamic code execution**. Main risks are **sensitive data in logs** and **non-encrypted local storage** for priorities. No critical vulnerabilities were found; recommendations focus on reducing information leakage and aligning with OWASP mobile best practices.

---

## 1. OWASP Mobile Top 10 / MASVS Mapping

| Area | Status | Notes |
|------|--------|-------|
| **M1 – Improper Platform Usage** | ✅ OK | Reminders permission requested with `NSRemindersUsageDescription`; `requestFullAccessToReminders()` (iOS 17+) used correctly. |
| **M2 – Insecure Data Storage** | ⚠️ Low risk | Priorities stored in `UserDefaults` / `@AppStorage` (not encrypted). Acceptable for non-sensitive text; see §2. |
| **M3 – Insecure Communication** | ✅ N/A | No network calls, no URLSession, no external APIs. |
| **M4 – Insecure Authentication** | ✅ N/A | No app-level auth; relies on device and Apple Reminders. |
| **M5 – Insufficient Cryptography** | ✅ N/A | No custom crypto; EventKit/Reminders use system protection. |
| **M6 – Insecure Authorization** | ✅ OK | EventKit authorization checked before loading/saving; status reflected in UI. |
| **M7 – Client Code Quality** | ⚠️ See §2 | Input validation present; logging is the main concern. |
| **M8 – Code Tampering** | ✅ Standard | No anti-tamper required for this app type. |
| **M9 – Reverse Engineering** | ✅ Standard | No hardcoded secrets; debug logs are the main leak. |
| **M10 – Extraneous Functionality** | ⚠️ High | Extensive `print()` of task titles, notes, tags, calendar names; see §2. |

---

## 2. Detailed Findings

### 2.1 [HIGH] Sensitive Data in Logs (OWASP M10, MASVS 4.2)

**Location:** `RemindersManager.swift`, `TaskCreationView.swift` – 100+ `print()` statements.

**Risk:** Task titles, notes, tags, delegate names, and calendar names are logged. On a shared device, in diagnostics, or via console, this can expose **personal and work-related content** (PII / business data).

**Examples:**
- `print("✅ Task created successfully: \(trimmedDescription)")`
- `print("   - Original notes: '\(task.notes)'")`
- `print("   Notes: '\(notes.prefix(200))'")`
- `print("   - \(delegate.displayName) (\(delegate.shortName))")`

**Recommendation:**
- Remove or guard all `print()` of user/reminder data in release builds (e.g. wrap in `#if DEBUG` or a `Logger` that is no-op in Release).
- If logging is needed in production, log only non-identifying info (e.g. counts, success/failure), never task text or delegate names.

**Applied:** All `print()` calls in `RemindersManager.swift` and `TaskCreationView.swift` are now wrapped in `#if DEBUG` / `#endif`, so they are compiled out in Release builds and no user/reminder data is logged in production.

---

### 2.2 [LOW] Priorities Stored in UserDefaults (OWASP M2)

**Location:** `PrioritiesView.swift`: `@AppStorage("priorities")`, `UserDefaults` for `lastPriorityReview`.

**Risk:** Data is stored in the app sandbox without encryption. Anyone with device backup or file access could read priorities text. Risk is **low** for typical “to-do” content but increases if users store sensitive goals.

**Recommendation:**
- For current use case: document that priorities are stored in plaintext in UserDefaults.
- If priorities are ever considered sensitive: store in Keychain (or encrypted container) and avoid logging their content.

---

### 2.3 [INFO] Input Validation and Injection

**Status:** ✅ No injection or unsafe regex observed.

- **Regex:** All `NSRegularExpression` patterns use **app-controlled** strings (e.g. `Quadrant.hashtag`, fixed tag names like `"donow"`). No user input is interpolated into regex – **ReDoS / injection risk avoided**.
- **UI:** User content (task title/notes, delegate names) is shown via SwiftUI `Text()` which does not interpret HTML/script – **XSS not applicable**.
- **EventKit:** Titles and notes are passed through to EventKit; EventKit handles encoding. No evidence of format-string or command injection.

**Recommendation:** When adding new features (e.g. Coach flows), continue to:
- Avoid building regex or SQL from raw user input.
- Use parameterized / type-safe APIs for any future persistence or queries.

---

### 2.4 [INFO] Permissions and Privacy

**Status:** ✅ Appropriate for Reminders usage.

- **Info.plist:** `NSRemindersUsageDescription` present and explains why reminders are needed.
- **Runtime:** Uses `requestFullAccessToReminders()` on supported versions; authorization status is checked before load/save.
- **Entitlements:** App Sandbox enabled; only `com.apple.security.files.user-selected.read-write` – minimal and correct for a reminders-focused app.

**Recommendation:** If you later add capabilities (e.g. Calendar, Notifications), add the corresponding usage descriptions and request only the minimum needed.

---

### 2.5 [INFO] Data in Apple Reminders

**Status:** ✅ Trust boundary is clear.

- Delegates and tasks are stored in the user’s Reminders (e.g. iCloud). Security is delegated to the system and the user’s account.
- App does not send reminder content to its own servers (no backend in scope).

**Recommendation:** If you ever sync to a custom backend, treat all reminder content as sensitive and use TLS and authentication; do not log full task/note text.

---

## 3. Positive Security Practices Observed

1. **No network:** No URLSession or external APIs – small attack surface.
2. **Sandbox:** Enabled with minimal entitlements.
3. **No dynamic code:** No `eval`, `NSPredicate` from user input, or script execution.
4. **Authorization checks:** Reminder access is gated on EventKit authorization before operations.
5. **Validation:** Empty/minimum length checks on task description and delegate names where it matters for UX and data integrity.

---

## 4. Recommendations Summary

| Priority | Action |
|----------|--------|
| **High** | ~~Remove or guard all `print()` of user/reminder data~~ **Done:** All prints wrapped in `#if DEBUG` in RemindersManager and TaskCreationView. |
| **Low** | Document that priorities are stored in UserDefaults unencrypted; consider Keychain if priorities become sensitive. |
| **Ongoing** | Keep regex and any new “query” logic free of user-controlled patterns; do not log PII in production. |

---

## 5. References

- [OWASP Mobile Top 10](https://owasp.org/www-project-mobile-top-10/)
- [OWASP MASVS](https://owasp.org/www-project-mobile-application-security-verification-standard/)
- [Apple – Protecting user privacy](https://developer.apple.com/documentation/uikit/protecting_the_user_s_privacy)
- [Apple – Secure coding guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/)

---

*Review date: 2025. Re-run after major feature or permission changes.*
