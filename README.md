# Synonyym

A lightweight macOS menubar app that instantly replaces any word with a French synonym using a single keyboard shortcut.

## Features

- **Global shortcut** (Cmd+Shift+S) works in any app
- **100% offline** — powered by the LibreOffice French thesaurus (36,000+ words)
- **Non-intrusive** — floating panel appears near the cursor without stealing focus
- **Keyboard-driven** — navigate with arrow keys, confirm with Enter, cancel with Escape
- **Clipboard-safe** — saves and restores your clipboard automatically
- **Menubar-only** — no Dock icon, lives quietly in your menu bar

## Requirements

- macOS 14.0+ (Sonoma)
- **Accessibility permission** (System Settings > Privacy & Security > Accessibility) — required to simulate keyboard events

## Build

```bash
xcodebuild -project Synonyym.xcodeproj -scheme Synonyym -configuration Debug build
```

Or open `Synonyym.xcodeproj` in Xcode and run with Cmd+R.

## Usage

1. Place your cursor on or next to a French word in any app
2. Press **Cmd+Shift+S**
3. A small panel appears with up to 5 synonyms
4. Use **arrow keys** to navigate, **Enter** to replace, **Escape** to cancel

The app automatically selects the word at the cursor, looks it up, and pastes the chosen synonym in place.

## Architecture

| Component | Role |
|---|---|
| `SynonyymApp` | App entry point, orchestrates the synonym flow |
| `HotkeyManager` | Carbon API global hotkey registration |
| `SynonymService` | Parses and queries the offline thesaurus |
| `TextInteractor` | CGEvent-based keyboard simulation (select, copy, paste) |
| `ClipboardManager` | Saves/restores pasteboard state |
| `SynonymPanel` | Non-activating `NSPanel` for the popup |
| `SynonymListView` | SwiftUI synonym list with keyboard navigation |

## Thesaurus

The French thesaurus (`thes_fr.dat`) comes from the [LibreOffice](https://www.libreoffice.org/) project, licensed under [LGPL 2.1+](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html). It contains 36,166 entries with an average of ~18 synonyms per word and is loaded into memory at launch for instant lookups.

## License

MIT
