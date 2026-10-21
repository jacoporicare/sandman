# AGENTS.md

Guidance for coding agents working in this repository.

Sandman is a macOS menu bar app (SwiftUI, macOS 27+, Xcode 27) that shows which apps are keeping the Mac awake. It has no dependencies and no test target.

## Commands

```bash
# Debug build (the way to check a change compiles)
xcodebuild -project Sandman.xcodeproj -scheme Sandman -configuration Debug -derivedDataPath build/DerivedData -quiet build

# Run it (quit any running Sandman first; it's a menu bar app, LSUIElement)
open build/DerivedData/Build/Products/Debug/Sandman.app

# Release build and install
xcodebuild -project Sandman.xcodeproj -scheme Sandman -configuration Release -derivedDataPath build/DerivedData build
ditto build/DerivedData/Build/Products/Release/Sandman.app /Applications/Sandman.app

# Ground truth to compare the UI against
pmset -g assertions
pmset -g log
```

The project uses a file-system-synchronized group, so new `.swift` files in `Sandman/` join the target without editing `project.pbxproj`.

`Design/AppIcon.swift` draws the app icon and is not part of the app target. Its header comment has the commands to regenerate the icon set.

## Trying a change

There's no test target, so check changes against the real system:

1. Quit any running Sandman, including the installed copy (`pkill -x Sandman`), then build Debug and `open` it. If Open at Login is on, the first launch stays in the menu bar; `open` it again to show the window.
2. Create real assertions: `caffeinate -d -t 60` keeps the display on, `caffeinate -i -t 60` keeps the Mac awake. Each one is listed under Background Activity for its first 10 seconds, then as a blocker. caffeinate lives in `/usr/bin`, so it's labelled as a macOS process.
3. Compare what Sandman shows with `pmset -g assertions`.

The Debug build has the same bundle identifier as the installed app, so it reads and writes the same `history.json`. History only records absences of 15 minutes or more, so it can't be checked quickly.

## Architecture

There are two `@Observable` models, created once in `SandmanApp` and passed to both scenes: the `MenuBarExtra` (`.window` style) and the `Window` with id `"main"`.

**Live state: `SleepAssertion` → `AssertionMonitor` → `Blocker`**
- `SleepAssertion.readAll()` reads powerd through `IOPMCopyAssertionsByProcess`. It turns raw names into readable reasons, for example coreaudiod device UIDs into "Playing audio on MacBook Pro Speakers" and runningboardd `app<…>` strings into plain text. It also classifies each assertion as `.display`, `.system` or `.background`. powerd's own "Prevent sleep while display is on" assertion is deliberately `.background`.
- `AssertionMonitor` polls every 2 s, because powerd only sends change notifications through private API. Each assertion belongs to `onBehalfOfPID ?? pid`, so the app that caused it gets the blame, not the daemon that holds it.
- `ProcessIdentity` resolves a pid to its outermost `.app` bundle, so helpers fold into their app. Its `id` is the bundle path for apps and `pid:<n>` otherwise.
- An owner only becomes a blocker after blocking continuously for `minimumBlockingDuration` (10 s). Until then it's listed under `background`. Only assign the published arrays when they actually change, to avoid needless SwiftUI updates.
- `canQuit`, `quit()` and `forceQuit()` never touch macOS system processes or launchd-started services. Before signalling, `send` checks that the pid still runs the same executable. Keep both guards.

**History: `AbsenceRecorder` → `Absence` (+ `PowerLog`)**
- `AbsenceRecorder` gets the monitor's blockers through a closure. It polls idle time (`CGEventSource`, no permission needed) every 5 s and listens for `NSWorkspace` will-sleep and did-wake notifications.
- An absence starts at your last input, once you've been idle for 60 s or the Mac sleeps. It ends at your next input. Background DarkWakes happen between will-sleep and did-wake, so they don't end it.
- Only absences of 15 minutes or more are kept. They're saved to `~/Library/Application Support/org.ricar.Sandman/history.json` (JSON `[Absence]`, newest first) and pruned after 30 days. `Absence` is `Codable` and persisted, so changing its fields needs to stay decodable for existing history files.
- Once an absence ends, `PowerLog.wakes` runs `pmset -g log` on a detached task and parses the Wake and DarkWake lines. The log format isn't documented, so lines that don't parse are skipped and never fail the absence.
- `AbsenceRecorder.init` takes `fileURL`, `idleTime`, `now` and `watchesSystem`, so it can be driven without the real system.

**UI**
- `MenuBarView` is the dropdown. `MainWindowView` has the Now and History tabs, and `HistoryViews` is the History tab's content.
- `SharedViews` holds the shared pieces, including `StateColor`. It's the single place for the asleep, awake and display-on colors (the asset-catalog colors `Sleep` and `DisplayOn`, plus indigo) and for the status symbol and tint.
- The window switches the activation policy to `.regular` while it's open, so Sandman appears in the Dock and ⌘-Tab, and back to `.accessory` when it closes. Launching the app again while it's running opens the window through `AppDelegate.applicationShouldHandleReopen`. When Open at Login is on, the window is suppressed at login.

## Build settings that shape the code

- `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` with approachable concurrency: everything is main-actor by default. Code that runs off the main actor (`PowerLog`, the `proc_*` helpers in `ProcessIdentity`) is marked `nonisolated` explicitly.
- Swift language mode 5.
- The app isn't sandboxed (`ENABLE_APP_SANDBOX = NO`), because it calls `proc_pidpath`/`proc_pidinfo`, sends signals and runs `/usr/bin/pmset`. Don't turn the sandbox on.

## Conventions

- Doc comments and UI text are plain, second-person English with a concrete example, and they explain *why*, for example the comment on `minimumBlockingDuration`.
- `README.md` states the user-visible numbers: the 2 s poll, the 10 s threshold, the 15-minute absence and 30-day retention. Update it when those constants or features change.
- Commit messages are one imperative sentence describing the user-visible change, e.g. "Record what kept the Mac awake while you were away".
