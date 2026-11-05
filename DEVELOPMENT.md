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
- The app provides adaptive navigation, native light/dark appearance, and Latvian/English/Russian strings.

## Phase 2 financial core (2026-11-05)

- `SalaryOSDomain` holds ISO currency, Decimal money, accounts, categories, ledger entries/postings, factories, validation, and repository interfaces.
- `SalaryOSPersistence` holds SwiftData records, a local persistence stack, and account/category/ledger repositories.
- Account accounting type, currency and opening balance are immutable for an ID. Assets have nonnegative opening balances; liabilities have nonpositive balances.
- Postings are balanced, positive-entry, single-currency double-entry operations. Cross-currency transfers require future FX support.
- Posting records store all entries together. Repositories reject duplicate IDs, missing/archived references, incompatible account/category kinds, and over-refunds.

## Phase 3 finance workflows (2026-11-05)

- Added account create/edit/archive/search flows and income/expense category creation.
- Added create/view/search/filter flows for income, expense, transfer, and refund operations. Posted operations can be duplicated, reversed, or corrected through an atomic reversal-plus-replacement; the original ledger record remains intact.
- Added an iPhone tab bar and macOS navigation sidebar.
- `SalaryOSApplication.LoadDashboardSnapshot` derives balances, monthly income/expenses, recent transactions, and six-month cash flow by currency from repositories.
- Dashboard sections can be hidden and reordered; widget settings currently persist locally on each device.
- All new UI text is present in Latvian, English, and Russian. No sample financial data is seeded.

### Verification

Both unsigned app builds completed successfully with Xcode 27.0:

```sh
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-iOS -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project SalaryOS.xcodeproj -scheme SalaryOS-macOS -sdk macosx -destination 'generic/platform=macOS' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

The local package test suite completed with **18 tests passed**: 11 domain, 5 SwiftData persistence, and 2 dashboard query tests.

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift test --scratch-path /tmp/SalaryOSDomainBuild
```

Xcode emits the App Intents metadata warning because the app does not link `AppIntents`; this project does not define App Intents. Persistence integration tests currently use an in-memory SwiftData store. Disk migration, CloudKit, cross-device widget settings, backup/restore, and conflict resolution remain future work.


## Phase 4 salary and tax engine (in progress)

- Added the standalone `SalaryOSTax` package target and an adaptive salary calculator screen in Latvian, English, and Russian.
- Added Latvia 2026 standard-employment monthly gross-to-net, employer cost, and annual progressive PIT estimate using `Decimal`.
- Rule set `LV-2026-v1` records effective dates, official sources, verification date, rates and thresholds. Unknown years fail closed.
- Calculation assumptions and exclusions are documented in `TAX_ENGINE.md`. This is an estimate, not annual return preparation.
