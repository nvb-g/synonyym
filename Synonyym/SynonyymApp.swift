import SwiftUI
import Carbon.HIToolbox
import os.log

private let logger = Logger(subsystem: "com.synonyym.app", category: "main")

// Also write to a file for easy debugging
private let logFile: URL = {
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("synonyym.log")
    // Clear log on launch
    try? "".write(to: url, atomically: true, encoding: .utf8)
    return url
}()

func slog(_ msg: String) {
    let line = "\(Date()): \(msg)\n"
    logger.info("\(msg)")
    if let data = line.data(using: .utf8),
       let fh = try? FileHandle(forWritingTo: logFile) {
        fh.seekToEndOfFile()
        fh.write(data)
        fh.closeFile()
    }
}

@main
struct SynonyymApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: "text.word.spacing")
                .imageScale(.medium)
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var hasAccessibilityPermission = false
    @Published var shortcutDisplayString: String = ""

    private let hotkeyManager = HotkeyManager()
    private let synonymService = SynonymService()
    private let translationService = TranslationService()
    private let textInteractor = TextInteractor()
    private let clipboardManager = ClipboardManager()
    private let synonymPanel = SynonymPanel()
    private var originalWord: String = ""
    private var clipboardChangeCountBeforeCapture: Int = 0
    private var caretRect: CGRect?
    private var isProcessing = false
    private var settingsWindow: NSWindow?

    init() {
        setupHotkey()
        hasAccessibilityPermission = AXIsProcessTrusted()
        slog("init — AXIsProcessTrusted = \(AXIsProcessTrusted())")
        slog("thesaurus entries = \(synonymService.entryCount)")
    }

    private func setupHotkey() {
        hotkeyManager.onHotkeyPressed = { [weak self] in
            self?.handleHotkeyPressed()
        }
        hotkeyManager.register()
        updateDisplayString()
    }

    private func updateDisplayString() {
        let config = ShortcutConfig(
            keyCode: hotkeyManager.currentKeyCode,
            modifiers: hotkeyManager.currentModifiers
        )
        shortcutDisplayString = config.displayString
    }

    func updateShortcut(keyCode: UInt32, modifiers: UInt32) {
        let config = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
        config.save()
        hotkeyManager.register(keyCode: keyCode, modifiers: modifiers)
        updateDisplayString()
        slog("shortcut updated: \(config.displayString)")
    }

    func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let currentConfig = ShortcutConfig(
            keyCode: hotkeyManager.currentKeyCode,
            modifiers: hotkeyManager.currentModifiers
        )

        let settingsView = SettingsView(currentConfig: currentConfig) { [weak self] keyCode, modifiers in
            self?.updateShortcut(keyCode: keyCode, modifiers: modifiers)
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 160),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Synonyym — Réglages"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }

    private func handleHotkeyPressed() {
        slog("hotkey pressed — panel visible: \(synonymPanel.isVisible), isProcessing: \(isProcessing)")

        guard !synonymPanel.isVisible else {
            synonymPanel.close()
            clipboardManager.restore()
            return
        }

        guard !isProcessing else {
            slog("already processing, ignoring hotkey")
            return
        }

        // Check Accessibility first
        let axTrusted = AXIsProcessTrusted()
        hasAccessibilityPermission = axTrusted
        slog("AXIsProcessTrusted = \(axTrusted)")

        if !axTrusted {
            slog("Accessibility OFF — showing error panel")
            showAccessibilityError()
            return
        }

        // 1. Save clipboard and capture caret position
        isProcessing = true
        clipboardManager.save()
        caretRect = textInteractor.getCaretRect()
        slog("caret rect: \(caretRect.map { "\($0)" } ?? "nil")")

        // 2. Select word before cursor (Option+Shift+Left)
        textInteractor.selectWordBeforeCursor()

        // 3. Read selected text — try AX API first, clipboard fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self = self else { return }

            // Primary: read selected text via Accessibility API (fast, no clipboard)
            if let text = self.textInteractor.getSelectedText() {
                let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                slog("AX selectedText: '\(cleaned)'")
                if !cleaned.isEmpty {
                    self.processWord(cleaned)
                    return
                }
            }

            // Fallback: copy to clipboard and read
            slog("AX selectedText failed, falling back to clipboard")
            self.clipboardChangeCountBeforeCapture = self.clipboardManager.changeCount
            self.textInteractor.copySelection()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.captureAndFetchSynonyms()
            }
        }
    }

    private func showAccessibilityError() {
        synonymPanel.show(
            synonyms: [],
            originalWord: "Accessibilité requise",
            onSelect: { _ in },
            onDismiss: { [weak self] in
                self?.synonymPanel.close()
            },
            errorMessage: "Activez Synonyym dans Réglages Système → Confidentialité → Accessibilité",
            shortcutDisplayString: shortcutDisplayString
        )
    }

    private func processWord(_ word: String) {
        originalWord = word
        let synonyms = synonymService.fetchSynonyms(for: word)
        slog("'\(word)' -> \(synonyms.count) synonyms: \(synonyms.map(\.word))")
        showPanel(synonyms: synonyms, originalWord: word)

        // Launch async translation (isFrench = word found in thesaurus)
        let isFrench = !synonyms.isEmpty
        translationService.translate(word: word, isFrench: isFrench) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let translated, let direction):
                self.synonymPanel.updateTranslation(.success(translated: translated, direction: direction))
            case .error(let message):
                self.synonymPanel.updateTranslation(.error(message))
            }
        }
    }

    private func captureAndFetchSynonyms() {
        let currentChangeCount = clipboardManager.changeCount
        let clipboardChanged = currentChangeCount != clipboardChangeCountBeforeCapture

        let raw = clipboardManager.readString()
        slog("clipboard content: '\(raw ?? "nil")' — changed: \(clipboardChanged)")

        // If clipboard didn't change, the word capture failed
        if !clipboardChanged {
            slog("clipboard unchanged — word capture failed")
            isProcessing = false
            clipboardManager.restore()
            // Show error: word capture didn't work
            synonymPanel.show(
                synonyms: [],
                originalWord: "Capture échouée",
                onSelect: { _ in },
                onDismiss: { [weak self] in
                    self?.synonymPanel.close()
                },
                errorMessage: "Impossible de capturer le mot. Vérifiez l'Accessibilité.",
                shortcutDisplayString: shortcutDisplayString
            )
            return
        }

        guard let word = raw,
              !word.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            slog("empty clipboard, showing feedback")
            isProcessing = false
            clipboardManager.restore()
            synonymPanel.show(
                synonyms: [],
                originalWord: "Aucun mot détecté",
                onSelect: { _ in },
                onDismiss: { [weak self] in
                    self?.synonymPanel.close()
                },
                errorMessage: "Placez le curseur après un mot et réessayez.",
                shortcutDisplayString: shortcutDisplayString
            )
            return
        }

        let cleanWord = word.trimmingCharacters(in: .whitespacesAndNewlines)
        processWord(cleanWord)
    }

    private func showPanel(synonyms: [Synonym], originalWord: String) {
        isProcessing = false
        synonymPanel.show(
            synonyms: synonyms,
            originalWord: originalWord,
            caretRect: caretRect,
            onSelect: { [weak self] synonym in
                self?.replaceSynonym(synonym)
            },
            onDismiss: { [weak self] in
                self?.dismissPanel()
            },
            onSelectTranslation: { [weak self] text in
                self?.replaceWithTranslation(text)
            },
            shortcutDisplayString: shortcutDisplayString
        )
    }

    private func replaceSynonym(_ synonym: Synonym) {
        synonymPanel.close()

        clipboardManager.writeString(synonym.word)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.textInteractor.pasteFromClipboard()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.clipboardManager.restore()
            }
        }
    }

    private func replaceWithTranslation(_ text: String) {
        synonymPanel.close()

        clipboardManager.writeString(text)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.textInteractor.pasteFromClipboard()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                self?.clipboardManager.restore()
            }
        }
    }

    private func dismissPanel() {
        synonymPanel.close()
        textInteractor.deselectText()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.clipboardManager.restore()
        }
    }
}
