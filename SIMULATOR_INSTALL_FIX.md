# Simulator installation error: Invalid placeholder attributes

This update adds explicit Info.plist files for the main app and WidgetKit extension instead of relying on generated placeholder metadata. It supplies the required bundle identity and package type keys, sets lowercase reverse-DNS bundle identifiers, and aligns the App Group identifier across the app, widget, entitlements, and setup notes.

## After opening in Xcode
1. Use Product > Clean Build Folder.
2. Delete the previous TutorMate app from the simulator if it is present.
3. Select the TutorMate scheme and an iOS simulator, then Build and Run.
4. If the same installer error remains, share the complete error details, especially the lines after `ID E R unOperationFailingWorker` / `User Info`; the first few lines alone do not identify the exact installer metadata field.

The project cannot be fully verified here because Apple's Xcode/iOS Simulator toolchain is unavailable in this environment. Firebase setup, signing, and App Group capability configuration may still be required on your Mac. The example App Group identifier must be registered/enabled for both targets in Xcode Signing & Capabilities before widget shared storage can work.
