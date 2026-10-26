# Xcode project parse-error repair

The original `project.pbxproj` contained malformed build-setting dictionaries: comma characters followed completed assignments, and the Face ID/NFC usage-description values were not quoted even though they contain spaces. Those syntax problems have been corrected.

Validation completed in this environment:
- `plutil -lint TutorMate.xcodeproj/project.pbxproj` reports `OK`.
- Every `.swift` file passed `swiftc -frontend -parse`.

Limitations:
- This environment does not include `xcodebuild` or the Apple iOS SDK, so this is not an Xcode build/test result.
- Open the project on a Mac, resolve Swift Package Manager dependencies, set signing and App Groups, add Firebase configuration, and run the app and test target before submission.


## Follow-up build fixes (2026-10-26)

- Replaced `List(selection:)` in `TutorRootView` with button-driven navigation because the single-selection initializer is unavailable for this iOS use.
- Updated `NFCService` delegate isolation using nonisolated callbacks and main-actor hops.
- Set `ALWAYS_SEARCH_USER_PATHS = NO` and `USE_HEADERMAP = YES` in the project build configurations.
- The archive and project syntax can be checked here, but an Xcode/iOS SDK build is not available in this environment.
