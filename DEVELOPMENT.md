# Development environment

## Phase 0 audit (2026-11-05)

### Repository and implementation

- The `SalaryOS` working directory was empty. It had no Git metadata, source files, Xcode project/workspace, package manifest, tests, or project-specific `AGENTS.md` instructions.
- There were no existing dependencies, entitlements, signing settings, or configured capabilities to preserve or assess.
- iOS and macOS deployment targets are not yet defined because no app target exists.
- No project build or test command exists yet.

### Toolchain

- Xcode 27.0 (build 27A266a) is installed at `/Applications/Xcode.app`.
- Xcode provides iOS 27.0, iOS Simulator 27.0, and macOS 27.0 SDKs.
- Swift 6.3.1 is available through the active Command Line Tools selection.
- The active `xcode-select` path is `/Library/Developer/CommandLineTools`. The developer directory could not be changed because it requires an administrator password. Xcode can be invoked directly at `/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild`.
- Build status: not applicable yet; there is no application project to build. No build or test has been reported as passing.

## Initial development plan

1. **Foundation:** create one shared SwiftUI app target for iOS and macOS, establish deployment targets supported by the chosen Xcode, and add app configuration, navigation, localization, design tokens, dependency composition, and an explicit persistence boundary. Build both platforms.
2. **Financial core:** define exact-decimal currency and money value types, account/category/transaction domain models, balanced ledger operations, repositories, and invariant-focused tests.
3. **Finance workflows:** persist accounts and transactions, then implement real dashboard summaries, search, filters, and charts from stored data.
4. **Latvian salary:** verify tax rules from official sources before adding versioned rule sets and isolated calculation logic with scenario tests.
5. **Planning features:** add debts, loans, budgets, savings, work time, and calendar in small independently reviewable increments.
6. **Portability and sync:** implement import/export and user-controlled backups before CloudKit synchronization; document capability and conflict requirements.
7. **External banking and release readiness:** evaluate provider constraints before implementing an adapter boundary; complete platform, privacy, accessibility, localization, migration, and release reviews only where the environment allows verification.

Each meaningful milestone should be built and relevant checks run before it is committed. Missing credentials, entitlements, services, or hardware will be documented as limits rather than reported as working integrations.
