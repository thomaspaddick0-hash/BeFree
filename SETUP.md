# BeFree — Xcode Setup Guide

## Step 1 — Prerequisites (do these first)

- [ ] Create Apple Developer account at developer.apple.com ($99/yr)
- [ ] Apply for FamilyControls entitlement: developer.apple.com/contact/request/family-controls-distribution
  - Describe use case as: "Personal screen time management — users voluntarily restrict themselves from apps and websites with accountability features"
- [ ] Create a Supabase project at supabase.com (free tier)
  - Run `supabase_schema.sql` in the Supabase SQL editor
  - Copy your Project URL and anon key
- [ ] Create a Resend account at resend.com (free tier)
  - Add and verify a sending domain
  - Create an API key

## Step 2 — Create the Xcode Project

1. Open Xcode → File → New → Project
2. Choose **App**, name it **BeFree**, set:
   - Bundle ID: `com.befree.app`
   - Interface: SwiftUI
   - Language: Swift
   - Minimum Deployment: iOS 16.0
3. Delete the auto-generated `ContentView.swift` and replace with the files in `BeFree/`

## Step 3 — Add App Extensions

For each extension:

### BeFreeShield (Shield Configuration + Shield Action)
File → New → Target → App Extension → **Shield Configuration Extension**
- Name: `BeFreeShield`
- Replace generated file with `BeFreeShield/ShieldConfigurationExtension.swift`
- Add a second source file: `BeFreeShield/ShieldActionExtension.swift`
- Change the extension's principal class in Info.plist to `ShieldActionExtension` for the action handler (or create two separate targets if you prefer)

### BeFreeMonitor (Device Activity Monitor)
File → New → Target → App Extension → **Device Activity Monitor Extension**
- Name: `BeFreeMonitor`
- Replace generated file with `BeFreeMonitor/DeviceActivityMonitorExtension.swift`

## Step 4 — Add Capabilities

For the **main BeFree target**:
- Signing & Capabilities → + → **Family Controls**
- Signing & Capabilities → + → **App Groups** → add `group.com.timetobefree.app`

For **BeFreeShield** and **BeFreeMonitor** targets:
- Signing & Capabilities → + → **App Groups** → add `group.com.timetobefree.app`

## Step 5 — Add Swift Packages

File → Add Package Dependencies:
- `https://github.com/supabase/supabase-swift` — add to main BeFree target only

## Step 6 — Fill in Your Keys

In `SupabaseService.swift`:
```swift
private let url = URL(string: "https://YOUR_PROJECT.supabase.co")!
private let anonKey = "YOUR_SUPABASE_ANON_KEY"
```

In `ResendService.swift`:
```swift
private let apiKey = "YOUR_RESEND_API_KEY"
private let fromAddress = "BeFree <noreply@yourdomain.com>"
```

## Step 7 — Register URL Scheme (for Shield deep link)

In `BeFree/Info.plist`, add:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>befree</string>
    </array>
  </dict>
</array>
```

## Step 8 — Run on a Real Device

**Simulator limitations:** FamilyActivityPicker works, but ManagedSettings blocking and Shield extensions only fire on a real device. Connect your iPhone and run directly to device.
