# App Icon Generation Instructions

The app icon matches the logo design in the app header (checkmark circle with lightning bolt on a blue-purple gradient background).

## Option 1: Using the AppIconGenerator View (Recommended)

1. Open `AppIconGenerator.swift` in Xcode
2. Run the preview or add it to a test view
3. Take screenshots at the required sizes:
   - 1024x1024 (for App Store and main icon)
   - 512x512 (for macOS)
   - 256x256 (for macOS)
   - 180x180 (for iPhone)
   - 167x167 (for iPad Pro)
   - 152x152 (for iPad)
   - 120x120 (for iPhone 2x)
   - 64x64, 32x32, 16x16 (for macOS smaller sizes)

4. Save the screenshots as PNG files with the names specified in `Contents.json`
5. Place them in `GetSh1tDone/Assets.xcassets/AppIcon.appiconset/`

## Option 2: Using a Design Tool

1. Create a 1024x1024 canvas
2. Add a blue-to-purple gradient background
3. Add a white checkmark circle (centered, slightly left)
4. Add an orange lightning bolt (to the right of the circle)
5. Export at all required sizes
6. Place in the AppIcon.appiconset folder

## Required Icon Sizes

### iOS:
- 1024x1024 (App Store)
- 180x180 (iPhone 3x)
- 120x120 (iPhone 2x)
- 167x167 (iPad Pro 2x)
- 152x152 (iPad 2x)

### macOS:
- 1024x1024 (2x for 512x512)
- 512x512 (1x for 512x512)
- 256x256 (both 1x and 2x)
- 128x128 (both 1x and 2x)
- 32x32 (both 1x and 2x)
- 16x16 (both 1x and 2x)

## Quick Method Using Xcode

1. In Xcode, select the AppIcon asset in Assets.xcassets
2. Drag and drop a 1024x1024 PNG image
3. Xcode will automatically generate all required sizes

Note: Make sure your 1024x1024 image matches the logo design from the app header.
