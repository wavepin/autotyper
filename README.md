<p align="center">
  <img src="Assets/AppIcon.png" width="128" height="128" alt="Autotyper icon">
</p>

<h1 align="center">Autotyper</h1>

<p align="center">A lightweight macOS menu bar app that types your text into other apps.</p>

Write or paste your text, choose a delay, and place your cursor where you want it typed. Autotyper runs locally and stays out of the Dock.

## Features

- Countdown presets: 3, 5, 10, 15, or 30 seconds.
- Fast typing with support for multiple lines, emoji, and special characters.
- Countdown and typing progress in the menu bar.
- Stop immediately by clicking the menu bar icon or using a keyboard shortcut.
- Local text history with reuse, individual deletion, and automatic expiry.
- Optional typing into password fields, with history saving skipped for those runs.

## Get started

Requires **macOS 14 or later**. Supports **Intel and Apple silicon**.

### Download

Download [Autotyper 1.0.0](https://github.com/wavepin/autotyper/releases/download/v1.0.0/Autotyper-1.0.0-universal.zip), unzip it, and move **Autotyper.app** to your **Applications** folder. Then open it and follow the setup steps below. The same download runs on Intel and Apple silicon.

Downloads require access to this private repository. See [Releases](https://github.com/wavepin/autotyper/releases) for release notes and checksums.

### Build from source

1. Install Apple Command Line Tools with `xcode-select --install`. You'll need Swift 6 or later, Python 3, and OpenSSL available in your terminal.
2. Clone the repository and build:

   ```sh
   git clone https://github.com/wavepin/autotyper.git
   cd autotyper
   ./script/build_and_run.sh
   ```

The script builds and opens `dist/Autotyper.app`. Open that app directly on subsequent launches.

To build an optimized app that runs on both Intel and Apple silicon:

```sh
./script/build_and_run.sh --universal
```

## Using Autotyper

1. Click the keyboard icon in the menu bar.
2. Grant Autotyper access in **System Settings → Privacy & Security → Accessibility** using the app's settings button.
3. Type or paste your text, choose a delay, and click **Start countdown**.
4. Click the destination text field before the countdown ends.

Leave the cursor in that field until typing finishes. Click the menu bar icon to stop at any time. Text already typed stays in the destination.

| Action | Shortcut |
| --- | --- |
| Open or close Autotyper | Control–Option–Command–T |
| Stop typing or cancel the countdown | Control–Option–Command–X |
| Start countdown from the composer | Command–Return |

Line breaks use **Shift–Return** by default for chat fields. For document editors, choose **Line breaks → Return (documents)** in the gear menu. Ordinary Return may submit a chat message. Some apps and protected fields may not accept automated input.

## History and privacy

Autotyper makes no network requests and never replaces your clipboard. Started texts are saved locally for **7 days** by default. Change the retention period or turn off history in the gear menu; use **Clear all** to remove existing entries.

History is stored unencrypted on your Mac. Saving is skipped whenever secure-field typing is enabled.

## Troubleshooting

**Accessibility is enabled, but typing will not start:** remove the old Autotyper entry in Accessibility Settings, add the current `dist/Autotyper.app`, enable it, and reopen the app.

**macOS warns about the app:** builds are signed for local use, not notarized for public distribution. If needed, use **Privacy & Security → Open Anyway** for a build you trust.
