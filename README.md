# Synonyym

A lightweight macOS menubar app for **French synonyms** and **FR/EN translation**, triggered by a single global shortcut.

## Features

- **Global shortcut** (`Cmd+Shift+S`) works in any application
- **French synonyms** — 100% offline, powered by the LibreOffice French thesaurus (36,000+ words)
- **FR ↔ EN translation** — powered by the [MyMemory Translation API](https://mymemory.translated.net/) (free, no API key required)
- **Multi-word support** — select a phrase before triggering the shortcut to translate entire sentences
- **Smart positioning** — floating panel appears near the cursor without stealing focus
- **Keyboard-driven** — full navigation with Tab, arrow keys, Enter, Escape
- **Clipboard-safe** — saves and restores your clipboard automatically
- **Resizable & movable** — drag and resize the panel as needed
- **Menubar-only** — no Dock icon, lives quietly in your menu bar

## Requirements

- macOS 14.0+ (Sonoma)
- **Accessibility permission** (System Settings > Privacy & Security > Accessibility) — required to simulate keyboard events via CGEvent

## Build

```bash
xcodebuild -project Synonyym.xcodeproj -scheme Synonyym -configuration Debug build
```

Or open `Synonyym.xcodeproj` in Xcode and run with `Cmd+R`.

## Usage

1. Place your cursor on or next to a word in any app (or select a phrase)
2. Press **Cmd+Shift+S**
3. A floating panel appears with synonyms and translation

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `⌘⇧S` | Open the panel |
| `Tab` | Switch between Synonyms and Translation tabs |
| `⇧Tab` | Swap translation direction (FR→EN ↔ EN→FR) |
| `↑/↓` | Navigate synonyms list |
| `Enter` | Replace the selected word with the chosen synonym/translation |
| `Escape` | Dismiss the panel |

## How it works

1. **Trigger** — `Cmd+Shift+S` saves the clipboard, selects the word at cursor (or uses existing selection), and reads it
2. **Synonym lookup** — the word is looked up in the offline French thesaurus (`thes_fr.dat`)
3. **Translation** — simultaneously, a request is sent to the MyMemory API for FR↔EN translation
4. **Display** — a non-activating floating panel appears near the cursor with both synonyms and translation
5. **Replace** — on Enter, the chosen synonym/translation is pasted in place and the clipboard is restored

### Synonym engine (offline)

French synonyms are powered by `thes_fr.dat` from the [LibreOffice](https://www.libreoffice.org/) project (LGPL 2.1+):
- 36,166 word entries, ~18 synonyms per word on average
- MyThes format (pipe-delimited text), loaded into memory at launch
- No network required — works entirely offline

### Translation engine (online)

Translation uses the [MyMemory Translation API](https://mymemory.translated.net/doc/spec.php):
- Free tier, no API key needed
- Supports FR→EN and EN→FR (swappable with `Shift+Tab`)
- Works with single words and full sentences
- Language direction is auto-detected: if the word is found in the French thesaurus, it translates FR→EN; otherwise EN→FR

## Architecture

| Component | Role |
|---|---|
| `SynonyymApp` | App entry point (`@main`), `MenuBarExtra`, `AppState` orchestrator |
| `HotkeyManager` | Carbon `RegisterEventHotKey` for global shortcut |
| `SynonymService` | Parses and queries the offline thesaurus (`thes_fr.dat`) |
| `TranslationService` | MyMemory API client for FR↔EN translation |
| `TextInteractor` | CGEvent-based keyboard simulation (select, copy, paste) + AX API for caret position |
| `ClipboardManager` | Saves/restores pasteboard state |
| `SynonymPanel` | Non-activating `NSPanel` with CGEvent tap for keyboard interception |
| `PanelContentView` | SwiftUI panel content with tabs (Synonyms / Translation) |
| `TranslationView` | Inline translation display |
| `SettingsView` | Shortcut customization window |

## Project structure

```
Synonyym/
├── SynonyymApp.swift          # @main, MenuBarExtra, AppState (orchestrator)
├── AppDelegate.swift          # Accessibility permission prompt
├── Services/
│   ├── HotkeyManager.swift    # Global hotkey via Carbon API
│   ├── SynonymService.swift   # Offline thesaurus (parses thes_fr.dat)
│   ├── TranslationService.swift # MyMemory translation API client
│   ├── TextInteractor.swift   # CGEvent keyboard simulation + AX API
│   └── ClipboardManager.swift # Save/restore clipboard
├── Views/
│   ├── SynonymPanel.swift     # Non-activating NSPanel + event handling
│   ├── PanelContentView.swift # SwiftUI panel content (tabs, list, footer)
│   ├── SynonymListView.swift  # SwiftUI synonym row
│   ├── TranslationView.swift  # Inline translation display
│   ├── SettingsView.swift     # Shortcut customization
│   └── MenuBarView.swift      # Menubar dropdown menu
├── Models/
│   └── Synonym.swift          # Data model
└── Resources/
    ├── Assets.xcassets        # Icons
    ├── thes_fr.dat            # LibreOffice French thesaurus (LGPL)
    └── Info.plist             # LSUIElement=true (no Dock icon)
```

## Current limitations

- Synonyms are **French only** (thesaurus is `thes_fr.dat`)
- Translation supports **French ↔ English** only
- MyMemory free tier has a rate limit (~5,000 words/day)
- Requires Accessibility permission for CGEvent keyboard simulation

## License

MIT — thesaurus file (`thes_fr.dat`) is [LGPL 2.1+](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html) from LibreOffice.
