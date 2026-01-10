# Code Signing Setup Instructions

## Issue: App ID Limit and Provisioning Profiles

You're encountering two issues:
1. **App ID limit reached** - You've created 10 App IDs in the last 7 days
2. **No provisioning profiles** - Xcode can't find profiles for the bundle identifier

## Solutions

### Option 1: Use Automatic Signing (Recommended for Development)

1. Open the project in Xcode
2. Select the **GetSh1tDone** project in the navigator
3. Select the **GetSh1tDone** target
4. Go to the **Signing & Capabilities** tab
5. Check **"Automatically manage signing"**
6. Select your **Team** from the dropdown (your Apple ID)
7. Xcode will automatically:
   - Create a new App ID if needed (or reuse an existing one)
   - Generate provisioning profiles
   - Handle code signing

**Note:** If you've hit the App ID limit, you may need to:
- Wait for the 7-day period to reset
- Or use an existing App ID by changing the bundle identifier

### Option 2: Change Bundle Identifier

If you want to use a different bundle identifier:

1. In Xcode, select the project
2. Select the target
3. Go to **General** tab
4. Change **Bundle Identifier** to something unique like:
   - `com.yourname.getsh1tdone`
   - `com.yourname.getsh1tdone.ios`
   - `com.yourcompany.getsh1tdone`

### Option 3: Use Simulator Only (No Signing Required)

If you just want to test in the iOS Simulator:
1. Select an iOS Simulator as your run destination
2. You don't need code signing for simulators
3. The app will run without provisioning profiles

### Option 4: Wait for App ID Limit Reset

The App ID limit resets every 7 days. You can:
- Wait until your limit resets
- Or delete unused App IDs from [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list)

## Quick Fix: Change Bundle Identifier in Xcode

The easiest solution is to change the bundle identifier in Xcode:

1. Open `GetSh1tDone.xcodeproj` in Xcode
2. Click on **GetSh1tDone** project (blue icon) in the left sidebar
3. Select **GetSh1tDone** under TARGETS
4. Click the **General** tab
5. Find **Bundle Identifier** and change it to something unique like:
   - `com.yourname.getsh1tdone.dev`
   - `com.yourname.getsh1tdone.$(USER)`
6. Go to **Signing & Capabilities** tab
7. Enable **"Automatically manage signing"**
8. Select your **Team**

This should resolve both errors!


