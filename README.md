# ThoughtCapture

A macOS menubar app for capturing thoughts with zero friction. Press **Option+T** anywhere to jot down an idea — it saves instantly to your Obsidian vault or Apple Notes.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2012%2B-blue" />
  <img src="https://img.shields.io/badge/swift-single%20file-orange" />
  <img src="https://img.shields.io/badge/license-MIT-green" />
</p>

## What it does

- **Option+T** opens a floating panel — type your thought, hit Enter, done
- **Select any text** in any app — a toolbar appears to save it with one click
- **Option+R** captures a screenshot region with your annotation
- A floating bubble shows your recent thoughts on hover — click to jump back to them
- Everything is saved with timestamps, source app, and URL context

## Install

### Option A: Download (recommended)

1. Download `ThoughtCapture.zip` from [Releases](../../releases)
2. Unzip and drag `ThoughtCapture.app` to `/Applications`
3. Open it — grant **Accessibility** permission when prompted
4. Click the menubar icon to configure your Obsidian vault path

### Option B: Build from source

```bash
# Requires Xcode Command Line Tools
xcode-select --install

# Clone and build
git clone https://github.com/YOUR_USERNAME/thought-capture.git
cd thought-capture
./build.sh

# Deploy to /Applications
./deploy.sh
```

### Permissions

On first launch, macOS will ask for:

- **Accessibility** — needed to read selected text from other apps
- **Automation (Notes)** — only if you choose Apple Notes as storage

Go to **System Settings > Privacy & Security > Accessibility** and add ThoughtCapture.

## Usage

| Shortcut | Action |
|----------|--------|
| **Option+T** | Capture a thought |
| **Option+R** | Screenshot + annotate |
| **Enter** | Save |
| **Esc** | Cancel |

### Storage

Choose between **Obsidian** or **Apple Notes** in Settings (click the menubar icon).

**Obsidian**: Thoughts are appended to a daily file in your vault at `01_daily/YYYY-MM-DD/Daily random thoughts.md` using callout blocks with color-coded timestamps.

**Apple Notes**: Thoughts are appended to a daily note called "Random Thoughts YYYY-MM-DD". Copied text appears in *italic* to distinguish it from your own words.

### Text selection

Select text in any app — a small toolbar appears near your cursor. Click the capture button to save the selection along with source context (app name, URL if in a browser).

## How it works

```
Option+T  -->  Swift app (single file, ~1700 lines)  -->  Obsidian vault / Apple Notes
                  |                                              |
                  |-- floating capture panel                     |-- daily markdown file
                  |-- selection toolbar (AX API)                 |-- callout blocks with timestamps
                  |-- screenshot capture                         |-- source attribution
                  |-- floating bubble + history
```

No server, no dependencies, no internet connection needed. Just a single Swift file compiled into a native macOS app.

## Requirements

- macOS 12+ (Monterey or later)
- Xcode Command Line Tools (for building from source)
- Obsidian (optional — Apple Notes works too)

## License

MIT
