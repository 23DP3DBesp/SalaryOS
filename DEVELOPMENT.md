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
- `SalaryOS/App/AppContainer.swift` is the composition root and creates the local SwiftData stack.
- `SalaryOS/Features/Navigation/AppRouter.swift` provides the initial adaptive sidebar and route.
- `SalaryOS/Resources/Localizable.xcstrings` establishes Latvian, English, and Russian localizations.
- `SalaryOS/Core/DesignSystem/Colors.swift` uses native system background colors, following light/dark appearance and accessibility settings.
- Startup storage failures show a localized diagnostic screen rather than crashing.

## Phase 2 financial core (2026-11-05)

- `SalaryOSDomain` holds ISO currency, Decimal money, accounts, categories, ledger entries/postings, factories, validation, and repository interfaces.
- `SalaryOSPersistence` holds SwiftData records, a local persistence stack, and account/category/ledger repositories.
- Account types, currency and opening balance are immutable for an ID. Asset opening balances are nonnegative; liability balances are nonpositive.
- A posting is a balanced, positive-entry, single-currency double-entry operation. Cross-currency transfers require future FX support.
- Posting records store all entries together. Repositories reject duplicate IDs, missing/archived references, incompatible account/category kinds, and over-refunds. Read operations surface decoding and persistence errors.
- Unit and in-memory persistence tests cover rounding, currency precision, ledger balancing, transfers, refunds, duplicate handling, reference integrity, persistence mapping, and account balances.

### Verification

Both unsigned app builds completed successfully with Xcode 27.0:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-iOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-macOS -sdk macosx -destination 'generic/platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The package test suite completed with **14 tests passed** (10 domain, 4 SwiftData repository tests) using the installed Xcode Swift toolchain:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --scratch-path /tmp/SalaryOSDomainBuild
```

The only remaining app build warning is Xcode's App Intents metadata extraction being skipped because the app does not link AppIntents; this project does not define App Intents. Persistence tests currently use an in-memory SwiftData store. Disk migration, CloudKit, and user-controlled backups have not been implemented.
