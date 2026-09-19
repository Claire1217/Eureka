<div align="center">

# Eureka

**Press a hotkey. Type a thought. Done.**

A tiny macOS menu bar app that saves a thought — together with the text you selected,<br>
the page you were on, or a screenshot — straight into Obsidian or Apple Notes.

[![Release](https://img.shields.io/github/v/release/Claire1217/Eureka)](https://github.com/Claire1217/Eureka/releases)
[![Build](https://github.com/Claire1217/Eureka/actions/workflows/build.yml/badge.svg)](https://github.com/Claire1217/Eureka/actions/workflows/build.yml)
[![macOS 12+](https://img.shields.io/badge/macOS-12%2B-black)](#install)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/Claire1217/Eureka?style=flat)](https://github.com/Claire1217/Eureka/stargazers)

[**Download**](https://github.com/Claire1217/Eureka/releases) · [Install](#install) · [Ask AI setup](#ask-ai-setup) · [简体中文](README.zh-CN.md)

</div>

<p align="center">
  <img src="assets/hero.svg" alt="Eureka demo: select text, press Option+T, type one line, press Enter — the thought lands in Obsidian as a colored card with its source" width="880">
</p>

Ideas show up while you are reading, coding or in a meeting — not while your notes app is open.
Switching apps to write one line costs more focus than the line is worth, so most of those
thoughts are lost. Eureka makes the cost one hotkey and one line, and it remembers *where* the
thought came from, so the note still makes sense next week.

## Three ways to capture

### <kbd>⌥</kbd> <kbd>T</kbd> &nbsp;A thought, with its context

Press the hotkey in any app and a small input appears at your cursor. Whatever you had selected is
quoted under your thought, with the page URL (Safari, Chrome, Edge, Brave, Arc) or the app name
as the source. Select nothing and it is just a quick note. **Enter** saves, **Esc** cancels —
you never leave what you were doing.

<table>
<tr>
<td width="50%" valign="top">

### <kbd>⌥</kbd> <kbd>R</kbd> &nbsp;A screenshot, with one line

<img src="assets/feature-screenshot.svg" alt="Screenshot capture: press Option+R, drag a region, type one line, press Enter — image and comment are saved as one card" width="100%">

Drag a region, say why it matters, press Enter. The image and your comment land in the same
card, so the chart you grabbed in a meeting still has its *"this spike = the 9am push"* next to
it a month later. No comment needed — Enter on an empty line saves just the image.

</td>
<td width="50%" valign="top">

### <kbd>/</kbd> &nbsp;Ask AI about what you selected

<img src="assets/feature-ask.svg" alt="AI quick answer: select text, press Option+T, type a slash and a question — the answer appears in the panel" width="100%">

Start the line with `/` and it becomes a question instead of a note. The text you selected is
sent along as context, and a short answer appears right in the panel — no tab switch, no
copy-paste. Bring your own key: DeepSeek, OpenAI, or a local model through Ollama
([setup](#ask-ai-setup)).

</td>
</tr>
</table>

**Also in the box**

- **Capture dot** — select text with the mouse and a small blue dot appears next to it; click it instead of reaching for the hotkey. Can be turned off in Settings.
- **Recent captures** — the floating bubble keeps your last 20 thoughts; click one to jump to it in Obsidian.
- **Obsidian or Apple Notes** — plain Markdown in your vault, or a daily note in Notes.
- **Yours to rebind** — both hotkeys are configurable, and every setting is scriptable.

## What lands in your notes

<p align="center">
  <img src="assets/obsidian-demo.png" alt="A day of thoughts captured with Eureka, shown as colored cards in Obsidian" width="760">
</p>

One file per day, one callout per thought:

```
your-vault/Eureka/
  2026-06-29/
    Thoughts.md       # every thought of the day
    attachments/      # screenshots
```

```markdown
> [!thought-coral] 11:03
> make job title optional — ask again after first use
> > Step 3: “Tell us about yourself” — 42% drop-off 【[mixpanel.com/funnels](https://…)】
```

It is a standard Obsidian callout, so the file stays readable in any editor. The colored cards
come from a small CSS snippet that Eureka installs into `.obsidian/snippets/` when you pick your
vault (reopen Obsidian if it was running). To install it by hand, copy
[`thought-cards.css`](thought-cards.css) there and enable it under Settings → Appearance → CSS snippets.

With **Apple Notes**, thoughts are appended to a note called `Thoughts — YYYY-MM-DD`. Notes cannot
take images through automation without losing earlier ones, so screenshots are saved to
`~/Pictures/Eureka/` and the note gets the file path.

## Install

Requires macOS 12 or later (Apple Silicon and Intel).

```bash
curl -fsSL https://raw.githubusercontent.com/Claire1217/Eureka/main/install.sh | bash
```

Or download the `.zip` from [Releases](https://github.com/Claire1217/Eureka/releases), unzip it
into `/Applications`, and remove the quarantine flag (the app is not notarized yet):

```bash
xattr -dr com.apple.quarantine /Applications/Eureka.app
```

**First launch**

1. **System Settings → Privacy & Security → Accessibility** → enable Eureka. This is what lets it read the text you have selected.
2. Pick your Obsidian vault (Eureka creates a `Eureka/` folder inside it), or choose Apple Notes.
3. That's it — press <kbd>⌥</kbd> <kbd>T</kbd>. Everything else lives under the **E!** menu bar icon → **Settings…**

> Releases are ad-hoc signed, so macOS asks for the Accessibility permission again after each
> update: remove the old Eureka entry from the list and add the new one.

## Cheat sheet

| | |
|---|---|
| <kbd>⌥</kbd> <kbd>T</kbd> | Capture a thought (with the current selection, if any) |
| <kbd>⌥</kbd> <kbd>R</kbd> | Screenshot a region, then comment |
| <kbd>Enter</kbd> | Save — on an empty line, saves just the selection or the screenshot |
| <kbd>Shift</kbd> <kbd>Enter</kbd> | New line |
| <kbd>/</kbd> + question | Ask AI instead of saving |
| <kbd>Esc</kbd> | Cancel / close the answer |

## Ask AI setup

Paste an API key under **E!** → **Settings…** and `/` questions work. DeepSeek is the default
because it is cheap and fast; any OpenAI-compatible chat completions endpoint works too:

| Provider | `llmApiBase` | `llmModel` |
|---|---|---|
| DeepSeek (default) | `https://api.deepseek.com/chat/completions` | `deepseek-chat` |
| OpenAI | `https://api.openai.com/v1/chat/completions` | e.g. `gpt-4o-mini` |
| Ollama (local, nothing leaves your Mac) | `http://localhost:11434/v1/chat/completions` | e.g. `llama3.2` |

```bash
defaults write com.eureka.app llmApiBase "http://localhost:11434/v1/chat/completions"
defaults write com.eureka.app llmModel "llama3.2"
defaults write com.eureka.app llmApiKey "ollama"     # any non-empty value for local models
killall Eureka; open /Applications/Eureka.app
```

Answers are short by design and come back in the language you asked in. To change the style:

```bash
defaults write com.eureka.app llmSystemPrompt "Answer in one short paragraph, plain words."
```

Answers are shown, not saved — if one is worth keeping, capture it as a thought.

## Privacy

Everything is written locally — to your vault folder or to Apple Notes. Eureka has no server,
no account and no analytics. The only network request it ever makes is a `/` question (your
question plus the selected text), sent to the endpoint you configured, and only when you ask.
Whatever was already on your clipboard is never saved: when an app does not expose its selection,
Eureka sends a ⌘C to read it and puts your previous clipboard back right after.

<details>
<summary><strong>All settings from the command line</strong></summary>

Everything in Settings is a `defaults` key, which also makes Eureka scriptable:

```bash
defaults write com.eureka.app vaultPath "/path/to/vault/Eureka"
defaults write com.eureka.app storageBackend "obsidian"        # or "notes"
defaults write com.eureka.app selectionToolbarEnabled -bool NO  # hide the capture dot
defaults write com.eureka.app llmApiKey "sk-your-key"
killall Eureka; open /Applications/Eureka.app
```

</details>

<details>
<summary><strong>Build from source</strong></summary>

```bash
git clone https://github.com/Claire1217/Eureka.git
cd Eureka && ./deploy.sh
```

Needs the Xcode command line tools. If you rebuild often, run `./setup_cert.sh` once and use
`./build.sh` — a stable signing identity keeps the Accessibility permission across rebuilds.
`./release.sh` produces the universal `.zip`; CI runs it on every push.

The README animations are generated: `python3 assets/make_hero.py` and
`python3 assets/make_features.py` (add `zh` for the Chinese variants).

</details>

<details>
<summary><strong>Install with an AI coding agent</strong></summary>

```bash
EUREKA_VAULT_PATH="/absolute/path/to/vault/Eureka" \
EUREKA_BACKEND="obsidian" \
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Claire1217/Eureka/main/install.sh)"
```

One step cannot be automated: System Settings → Privacy & Security → Accessibility → enable Eureka.

</details>

## Known limitations

- <kbd>⌥</kbd> <kbd>T</kbd> and <kbd>⌥</kbd> <kbd>R</kbd> normally type `†` and `®`; pick other hotkeys in Settings if you need those characters.
- Some Electron apps do not expose their selection, so Eureka falls back to ⌘C there. In editors that copy the whole line when nothing is selected (VS Code), that line can show up as context.
- Source URLs are only captured from the browsers listed above (Firefox has no scripting interface).
- The UI is light-mode only for now.

## License

[MIT](LICENSE)
