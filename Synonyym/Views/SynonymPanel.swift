import SwiftUI
import AppKit
import Carbon.HIToolbox

final class SynonymPanel {
    private var panel: NSPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var selectedIndex: Int = 0
    private var synonyms: [Synonym] = []
    private var originalWord: String = ""
    private var errorMessage: String?
    private var shortcutDisplayString: String = "⌘⇧S"
    private var onSelect: ((Synonym) -> Void)?
    private var onDismiss: (() -> Void)?
    private var onSelectTranslation: ((String) -> Void)?

    // Translation state
    private var activeTab: PanelTab = .synonymes
    private var translationState: TranslationState = .loading
    private var translationResult: String?

    // Static reference for the C callback
    private static var current: SynonymPanel?

    func show(
        synonyms: [Synonym],
        originalWord: String,
        caretRect: CGRect? = nil,
        onSelect: @escaping (Synonym) -> Void,
        onDismiss: @escaping () -> Void,
        onSelectTranslation: @escaping (String) -> Void = { _ in },
        errorMessage: String? = nil,
        shortcutDisplayString: String = "⌘⇧S"
    ) {
        close()

        self.synonyms = synonyms
        self.originalWord = originalWord
        self.selectedIndex = 0
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self.onSelectTranslation = onSelectTranslation
        self.errorMessage = errorMessage
        self.shortcutDisplayString = shortcutDisplayString
        self.activeTab = .synonymes
        self.translationState = .loading
        self.translationResult = nil
        SynonymPanel.current = self

        // Create the panel
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: true
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setHostingView(on: panel)

        let panelSize = NSSize(width: 240, height: computeHeight())
        let origin = computeOrigin(panelSize: panelSize, caretRect: caretRect)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)

        // Show with animation
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel

        // Try CGEvent tap first (needs Accessibility)
        installEventTap()

        // Always install global NSEvent monitors as fallback
        installGlobalMonitors()

        slog("panel shown: \(synonyms.count) synonyms, eventTap: \(eventTap != nil)")
    }

    func close() {
        removeEventTap()
        removeGlobalMonitors()

        if let panel = panel {
            panel.orderOut(nil)
            self.panel = nil
        }

        synonyms = []
        originalWord = ""
        errorMessage = nil
        onSelect = nil
        onDismiss = nil
        onSelectTranslation = nil
        activeTab = .synonymes
        translationState = .loading
        translationResult = nil
        SynonymPanel.current = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func updateTranslation(_ state: TranslationState) {
        translationState = state
        if case .success(let translated, _) = state {
            translationResult = translated
        } else {
            translationResult = nil
        }
        refreshContent()
        resizePanel()
    }

    // MARK: - Tab switching

    private func switchTab() {
        activeTab = (activeTab == .synonymes) ? .traduction : .synonymes
        refreshContent()
        resizePanel()
    }

    private func resizePanel() {
        guard let panel = panel else { return }
        let newHeight = computeHeight()
        var frame = panel.frame
        let heightDiff = newHeight - frame.height
        frame.origin.y -= heightDiff
        frame.size.height = newHeight
        panel.setFrame(frame, display: true)
    }

    // MARK: - Global NSEvent Monitors (fallback, always works)

    private func installGlobalMonitors() {
        // Keyboard monitor — catches Esc, arrows, Return from other apps
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKey(event)
        }

        // Click outside monitor
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.panel else { return }
            if !panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async {
                    self.onDismiss?()
                }
            }
        }
    }

    private func removeGlobalMonitors() {
        if let m = globalKeyMonitor { NSEvent.removeMonitor(m); globalKeyMonitor = nil }
        if let m = globalClickMonitor { NSEvent.removeMonitor(m); globalClickMonitor = nil }
    }

    private func handleGlobalKey(_ event: NSEvent) {
        // Skip if CGEvent tap is active (it handles keys already)
        if eventTap != nil { return }

        switch Int(event.keyCode) {
        case kVK_Tab:
            switchTab()

        case kVK_DownArrow:
            if activeTab == .synonymes && !synonyms.isEmpty {
                selectedIndex = min(selectedIndex + 1, synonyms.count - 1)
                refreshContent()
            }
        case kVK_UpArrow:
            if activeTab == .synonymes && !synonyms.isEmpty {
                selectedIndex = max(selectedIndex - 1, 0)
                refreshContent()
            }
        case kVK_Return:
            if activeTab == .synonymes {
                if !synonyms.isEmpty && selectedIndex < synonyms.count {
                    let synonym = synonyms[selectedIndex]
                    onSelect?(synonym)
                }
            } else if activeTab == .traduction {
                if let result = translationResult {
                    onSelectTranslation?(result)
                }
            }
        case kVK_Escape:
            onDismiss?()
        default:
            break
        }
    }

    // MARK: - CGEvent Tap (intercepts + swallows keys, needs Accessibility)

    private func installEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard let panel = SynonymPanel.current else {
                    return Unmanaged.passUnretained(event)
                }

                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                switch Int(keyCode) {
                case kVK_Tab:
                    DispatchQueue.main.async {
                        panel.switchTab()
                    }
                    return nil

                case kVK_DownArrow:
                    DispatchQueue.main.async {
                        if panel.activeTab == .synonymes && !panel.synonyms.isEmpty {
                            panel.selectedIndex = min(panel.selectedIndex + 1, panel.synonyms.count - 1)
                            panel.refreshContent()
                        }
                    }
                    return nil

                case kVK_UpArrow:
                    DispatchQueue.main.async {
                        if panel.activeTab == .synonymes && !panel.synonyms.isEmpty {
                            panel.selectedIndex = max(panel.selectedIndex - 1, 0)
                            panel.refreshContent()
                        }
                    }
                    return nil

                case kVK_Return:
                    DispatchQueue.main.async {
                        if panel.activeTab == .synonymes {
                            if !panel.synonyms.isEmpty && panel.selectedIndex < panel.synonyms.count {
                                let synonym = panel.synonyms[panel.selectedIndex]
                                panel.onSelect?(synonym)
                            }
                        } else if panel.activeTab == .traduction {
                            if let result = panel.translationResult {
                                panel.onSelectTranslation?(result)
                            }
                        }
                    }
                    return nil

                case kVK_Escape:
                    DispatchQueue.main.async {
                        panel.onDismiss?()
                    }
                    return nil

                default:
                    return Unmanaged.passUnretained(event)
                }
            },
            userInfo: nil
        )

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            if let runLoopSource = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            }
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    private func removeEventTap() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            if let runLoopSource = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
                self.runLoopSource = nil
            }
            self.eventTap = nil
        }
    }

    // MARK: - Content

    private func setHostingView(on panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        contentView.subviews.forEach { $0.removeFromSuperview() }

        let selectedBinding = Binding<Int>(
            get: { [weak self] in self?.selectedIndex ?? 0 },
            set: { [weak self] in self?.selectedIndex = $0 }
        )

        let tabBinding = Binding<PanelTab>(
            get: { [weak self] in self?.activeTab ?? .synonymes },
            set: { [weak self] newTab in
                self?.activeTab = newTab
                self?.resizePanel()
            }
        )

        let currentSynonyms = self.synonyms
        let capturedOnSelect = self.onSelect
        let capturedOnSelectTranslation = self.onSelectTranslation
        let capturedOnDismiss = self.onDismiss
        let word = self.originalWord
        let shortcut = self.shortcutDisplayString
        let error = self.errorMessage
        let currentTranslationState = self.translationState

        let hostingView = NSHostingView(
            rootView: PanelContentView(
                synonyms: currentSynonyms,
                selectedIndex: selectedBinding,
                activeTab: tabBinding,
                translationState: currentTranslationState,
                onSelect: { synonym in
                    capturedOnSelect?(synonym)
                },
                onSelectTranslation: { translated in
                    capturedOnSelectTranslation?(translated)
                },
                onDismiss: {
                    capturedOnDismiss?()
                },
                originalWord: word,
                shortcutDisplayString: shortcut,
                errorMessage: error
            )
        )
        hostingView.frame = contentView.bounds
        hostingView.autoresizingMask = [.width, .height]
        contentView.addSubview(hostingView)
    }

    private func refreshContent() {
        guard let panel = panel else { return }
        setHostingView(on: panel)
    }

    /// Position the panel near the text caret, avoiding overlap with the word.
    /// Falls back to mouse position if caret rect is unavailable.
    private func computeOrigin(panelSize: NSSize, caretRect: CGRect?) -> NSPoint {
        guard let screen = NSScreen.main else {
            return NSPoint(x: 100, y: 100)
        }
        let screenFrame = screen.visibleFrame
        let margin: CGFloat = 8
        let gap: CGFloat = 4 // gap between caret and panel

        // Anchor point: caret position or mouse position
        let anchor: NSPoint
        if let caret = caretRect {
            // Use bottom-left of caret rect as anchor
            anchor = NSPoint(x: caret.origin.x, y: caret.origin.y)
        } else {
            anchor = NSEvent.mouseLocation
        }

        var x: CGFloat
        var y: CGFloat

        // Vertical: prefer below the caret line, flip above if not enough room
        if let caret = caretRect {
            let spaceBelow = anchor.y - screenFrame.minY
            if spaceBelow >= panelSize.height + gap {
                // Place below the caret
                y = anchor.y - panelSize.height - gap
            } else {
                // Place above the caret
                y = caret.maxY + gap
            }
        } else {
            // Mouse fallback: below cursor
            let spaceBelow = anchor.y - screenFrame.minY
            if spaceBelow >= panelSize.height + gap {
                y = anchor.y - panelSize.height - gap
            } else {
                y = anchor.y + 20 + gap
            }
        }

        // Horizontal: align left edge with caret, shift if needed
        x = anchor.x

        // If panel would go off the right edge, shift left
        if x + panelSize.width > screenFrame.maxX - margin {
            x = screenFrame.maxX - panelSize.width - margin
        }
        // If panel would go off the left edge, shift right
        if x < screenFrame.minX + margin {
            x = screenFrame.minX + margin
        }

        // Clamp vertical
        y = max(screenFrame.minY + margin, min(y, screenFrame.maxY - panelSize.height - margin))

        return NSPoint(x: x, y: y)
    }

    private func computeHeight() -> CGFloat {
        if errorMessage != nil {
            return 110
        }

        // Tab bar height + header
        let headerAndTabs: CGFloat = 60

        switch activeTab {
        case .synonymes:
            if synonyms.isEmpty {
                return headerAndTabs + 50 + 20 // "Aucun synonyme" + footer
            }
            let contentHeight = CGFloat(synonyms.count * 28 + 12)
            return headerAndTabs + min(contentHeight, 168) + 20 // +20 for footer
        case .traduction:
            return headerAndTabs + 70 + 20 // translation content + footer
        }
    }
}
