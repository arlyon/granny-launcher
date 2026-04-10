# 👵 Granny Launcher
**A high-contrast, safety-first Android launcher designed specifically for seniors.**

Granny Launcher strips away the complexity of modern smartphones, replacing the "UI labyrinth" with a high-visibility, simplified experience. It focuses on what matters: staying connected, staying safe, and being legible.

---

## ✨ Key Features

- 🟡 High Contrast UI: Optimized for visual clarity using a specialized Black & Yellow theme.
- 🆘 One-Tap SOS: Triggers an immediate phone call and sends an SMS with the user's live GPS location to a designated emergency contact.
- 📌 Pinned Essentials: Admin-controlled pinning for up to 6 contacts and 8 apps to prevent clutter.
- 📏 Adaptive Scaling: 5 levels of UI scaling (XS to XL) that override system settings.
- 🔒 Kiosk Mode: When set as Device Owner, it locks the status bar and prevents accidental exits.
- 🔔 Smart Notifs: Massive, readable tiles for missed calls and messages.

---

## 🛠 The "Silent" Update Process

Granny Launcher is designed to be maintained remotely, so the user never has to interact with a confusing "Install" prompt.

1. The Check: On every boot (and periodically via WorkManager), the app fetches a version.json from the remote repository.
   Target: https://github.com/arlyon/granny-launcher/releases/download/latest/version.json

2. The Download: If a newer version is found, the UpdateService uses the Dio library to download the latest .apk into secure temporary storage.

3. The Silent Installation (Native Power): Instead of using a standard Intent, the app invokes a native Kotlin PackageInstaller session.

Note: Silent Installation requires the app to be set as the Device Owner.

- Kotlin Session: The app opens a PackageInstaller.Session, streams the APK bytes, and commits.
- The Handover: The Android system replaces the app in the background.
- The Result: UpdateReceiver logs the success, and the launcher restarts automatically.

---

## 🚀 Setup & Installation

To unlock Kiosk Mode and Silent Updates, you must grant the app Device Owner status via ADB.

1. Install the APK via usual methods.
2. Enable USB Debugging on the device.
3. Run the following ADB command:

```
adb shell dpm set-device-owner com.example.granny_launcher/.DeviceAdminReceiver
```

### Post-Installation Checklist
- [ ] Set Granny Launcher as the Default Home App.
- [ ] Grant Notification Access in System Settings.
- [ ] Grant SMS, Phone, and Location permissions.
- [ ] (Optional) Disable Edge Panels and Bixby side-keys.

---

## 🏗 Tech Stack
- Framework: Flutter (Dart)
- Native Core: Kotlin (DevicePolicyManager, PackageInstaller API)
- Background Tasks: WorkManager
- State Management: ValueNotifiers
- Storage: SharedPreferences

---

## 🔒 Security & Privacy
- No Cloud: All pinning data is stored locally on the device.
- Admin Panel: Manage settings using an admin panel, openable by clicking 'home' 10 times in a row.
- Admin PIN: Settings are protected by a 4-digit PIN (Default: 1996).
- Direct SMS: SOS messages are sent via SmsManager API for maximum reliability.

---

*Built with ❤️ to keep our grandparents connected.*
