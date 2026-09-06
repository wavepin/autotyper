# Autotyper

A small, local menu bar utility for macOS 14 or later. Native SwiftUI + AppKit,
no dependencies, accounts, network connections, or clipboard replacement.

## Use

Open `dist/Autotyper.app`. The keyboard icon lives in the menu bar; there is
intentionally no Dock icon. The composer opens on launch.

1. Enable **Autotyper** in System Settings → Privacy & Security → Accessibility
   when prompted. The app needs this macOS permission to send keyboard input.
2. Enter text or use **Paste**. Pick a 3, 5, 10, 15, or 30 second countdown.
3. Click **Start countdown** (or ⌘Return) and click the destination text field.
4. Watch the menu bar countdown, then typing progress.
5. Click the menu bar icon during either stage to cancel immediately.

Global shortcuts:

- **⌃⌥⌘T**: open/close the composer (also cancels an active operation).
- **⌃⌥⌘X**: cancel without opening the composer.

Normal pace sends approximately 250 Unicode graphemes per second; actual speed
includes OS and destination overhead. **Compatibility pace** uses approximately
50 per second for slower fields. The delay and pace are remembered.

Newlines, tabs, bullets, non-Latin text, and emoji are sent as Unicode, not
physical Return/Tab keys. Literal `\n` and `\t` remain literal text. CRLF and CR
line endings normalize to LF. The app does not append Return or press Submit.
It stops when the foreground app changes, secure input is enabled, a password
field is detected, or a modifier key is held. Leave the cursor in the same field
until completion: switching fields inside one app is not detected.

Some games, terminals, remote desktops, custom web editors, and protected fields
may reject or transform synthetic Unicode input. Single-line fields may discard
line breaks. Completion means events were sent; macOS cannot guarantee that a
particular destination accepted every character. Cancelling stops further events;
it cannot retract text or events the destination already received. The clipboard
is read only when you press Paste and is never replaced.

## History and privacy

Started texts are saved locally, including cancelled attempts. Duplicate texts
move to the top. History keeps at most 100 entries and defaults to seven days;
choose 1, 3, 7, 14, or 30 days from the gear menu, or disable future saving.
Select an entry to reuse it, delete a single entry, or clear all with confirmation.
Expiry runs at launch, on opening, on save, and every minute while running.
When the app is closed, old entries are removed at the next launch.

History is **unencrypted** JSON at
`~/Library/Application Support/Autotyper/history.json`, with owner-only file
permissions. The current unstarted draft is memory-only and disappears at quit.
Disabling history does not remove existing entries; use Clear all for that.

## Build and run

Requires Swift 6 / Apple Command Line Tools. No Xcode project or third-party
packages are required. Open `Package.swift` in Xcode if desired.

```sh
./script/build_and_run.sh              # native debug build and launch
./script/build_and_run.sh --verify     # build, launch, verify process
./script/build_and_run.sh --universal  # optimized Intel + Apple silicon app
./script/build_and_run.sh --build      # build the native bundle without launch
./script/swift.sh run AutotyperChecks  # Unicode, CGEvent, and history checks
```

`--debug`, `--logs`, and `--telemetry` are also supported. The Codex Run action
uses the same build/run script. Universal builds contain x86_64 and arm64 slices.
The generated app is ad-hoc signed for local use, not Developer ID signed or
notarized for public distribution. After rebuilding, macOS may require toggling
or re-adding its Accessibility entry. Keep the app at a stable path.

`script/swift.sh` applies a project-local VFS overlay if an upgraded Command Line
Tools installation has outdated private SwiftPM interfaces alongside newer public
interfaces, and hides a duplicate legacy Swift bridging module map when present.
It does not modify the installed toolchain.

The checks use a dependency-free executable harness because standalone Apple
Command Line Tools do not include XCTest. No Accessibility permission is needed
for these checks; they create keyboard events but never post them.

## Structure

- `Sources/Autotyper/App`: menu bar lifecycle and popover bridge.
- `Sources/Autotyper/Views`: native SwiftUI composer and history.
- `Sources/Autotyper/Services`: paced keyboard events and Carbon global shortcuts.
- `Sources/Autotyper/Stores`: local history and retention settings.
- `Sources/AutotyperCore`: Unicode packetization and retention policy.
- `Tests/AutotyperCoreTests`: long-text, Unicode, escape, and expiry checks.
