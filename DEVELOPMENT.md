# Development environment

## Phase 0 audit (2026-11-05)

- The `SalaryOS` working directory was empty. It had no Git metadata, source files, Xcode project/workspace, package manifest, tests, or project-specific `AGENTS.md` instructions.
- There were no existing dependencies, entitlements, signing settings, or configured capabilities to preserve or assess.
- Xcode 27.0 (build 27A266a) is installed at `/Applications/Xcode.app` and provides iOS 27.0, iOS Simulator 27.0, and macOS 27.0 SDKs.
- Swift 6.3.1 is available. The active `xcode-select` path remains `/Library/Developer/CommandLineTools`; changing it requires an administrator password. Invoke Xcode directly at `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`.

## Phase 1 foundation (2026-11-05)

Created a shared SwiftUI codebase with two native app targets in `SalaryOS.xcodeproj`:

- `SalaryOS-iOS`: iOS deployment target 17.0; iPhone and iPad.
- `SalaryOS-macOS`: macOS deployment target 14.0.
- Both targets use Swift 6 language mode and complete strict concurrency checking.
- `SalaryOS/App/AppContainer.swift` composes the local SwiftData container. The schema is intentionally empty until financial domain models are designed in Phase 2.
- `SalaryOS/Features/Navigation/AppRouter.swift` provides the initial adaptive sidebar and route.
- `SalaryOS/Resources/Localizable.xcstrings` establishes Latvian, English, and Russian localizations.
- `SalaryOS/Core/DesignSystem/Colors.swift` uses native system background colors, following light/dark appearance and accessibility settings.
- Startup storage failures show a localized diagnostic screen rather than crashing.
- No external dependencies, CloudKit entitlement, banking integration, or sample financial data were added.

### Verification

Both unsigned simulator/device builds completed successfully with Xcode 27.0:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-iOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-macOS -sdk macosx -destination 'generic/platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The only remaining build warning is Xcode's App Intents metadata extraction being skipped because the app does not link AppIntents; this foundation does not define App Intents. No tests exist yet; tests will be introduced with the domain they verify.
