import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - Cursor overlay (transparent, uses NSTrackingArea with .activeAlways)

private class CursorEdgeOverlay: NSView {
    private let edgeWidth: CGFloat = 6

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let b = bounds
        let onLeft = p.x <= edgeWidth
        let onRight = p.x >= b.width - edgeWidth
        let onBottom = p.y <= edgeWidth
        let onTop = p.y >= b.height - edgeWidth

        if (onLeft || onRight) && (onTop || onBottom) {
            NSCursor.openHand.set()
        } else if onLeft || onRight {
            NSCursor.resizeLeftRight.set()
        } else if onTop || onBottom {
            NSCursor.resizeUpDown.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    // Transparent to all clicks — only handles cursor appearance
    override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
}

// MARK: - Observable panel state

final class PanelState: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var activeTab: PanelTab = .synonymes
    @Published var translationState: TranslationState = .loading
}

// MARK: - Panel

final class SynonymPanel {
    private var panel: NSPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalKeyMonitor: Any?
    private var globalClickMonitor: Any?
    private var synonyms: [Synonym] = []
    private var originalWord: String = ""
    private var errorMessage: String?
    private var shortcutDisplayString: String = "⌘⇧S"
    private var onSelect: ((Synonym) -> Void)?
    private var onDismiss: (() -> Void)?
    private var onSelectTranslation: ((String) -> Void)?
    var onSwapTranslation: (() -> Void)?

    private var translationResult: String?
    private let panelState = PanelState()
    private static var current: SynonymPanel?

    func show(
        synonyms: [Synonym],
        originalWord: String,
        caretRect: CGRect? = nil,
        onSelect: @escaping (Synonym) -> Void,
        onDismiss: @escaping () -> Void,
        onSelectTranslation: @escaping (String) -> Void = { _ in },
        onSwapTranslation: (() -> Void)? = nil,
        errorMessage: String? = nil,
        shortcutDisplayString: String = "⌘⇧S"
    ) {
        close()

        self.synonyms = synonyms
        self.originalWord = originalWord
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        self.onSelectTranslation = onSelectTranslation
        self.onSwapTranslation = onSwapTranslation
        self.errorMessage = errorMessage
        self.shortcutDisplayString = shortcutDisplayString
        self.translationResult = nil

        panelState.selectedIndex = 0
        panelState.activeTab = .synonymes
        panelState.translationState = .loading

        SynonymPanel.current = self

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .resizable],
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
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 120, height: 80)
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setHostingView(on: panel)

        let panelSize = NSSize(width: 240, height: computeHeight())
        let origin = computeOrigin(panelSize: panelSize, caretRect: caretRect)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: true)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        installEventTap()
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
        onSwapTranslation = nil
        translationResult = nil

        panelState.selectedIndex = 0
        panelState.activeTab = .synonymes
        panelState.translationState = .loading

        SynonymPanel.current = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func updateTranslation(_ state: TranslationState) {
        panelState.translationState = state
        if case .success(let translated, _) = state {
            translationResult = translated
        } else {
            translationResult = nil
        }
        resizePanel()
    }

    // MARK: - Tab switching

    private func switchTab() {
        panelState.activeTab = (panelState.activeTab == .synonymes) ? .traduction : .synonymes
        resizePanel()
    }

    private func resizePanel(forceWidth: CGFloat? = nil) {
        guard let panel = panel else { return }
        let newHeight = computeHeight()
        var frame = panel.frame
        let heightDiff = newHeight - frame.height
        frame.origin.y -= heightDiff
        frame.size.height = newHeight
        if let w = forceWidth {
            frame.size.width = w
        }
        panel.setFrame(frame, display: true)
    }

    // MARK: - Global NSEvent Monitors

    private func installGlobalMonitors() {
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKey(event)
        }

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
        if eventTap != nil { return }

        switch Int(event.keyCode) {
        case kVK_Tab:
            if event.modifierFlags.contains(.shift) && panelState.activeTab == .traduction {
                onSwapTranslation?()
            } else {
                switchTab()
            }

        case kVK_DownArrow:
            if panelState.activeTab == .synonymes && !synonyms.isEmpty {
                panelState.selectedIndex = min(panelState.selectedIndex + 1, synonyms.count - 1)
            }
        case kVK_UpArrow:
            if panelState.activeTab == .synonymes && !synonyms.isEmpty {
                panelState.selectedIndex = max(panelState.selectedIndex - 1, 0)
            }
        case kVK_Return:
            if panelState.activeTab == .synonymes {
                if !synonyms.isEmpty && panelState.selectedIndex < synonyms.count {
                    let synonym = synonyms[panelState.selectedIndex]
                    onSelect?(synonym)
                }
            } else if panelState.activeTab == .traduction {
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

    // MARK: - CGEvent Tap

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
                    let shiftPressed = event.flags.contains(.maskShift)
                    DispatchQueue.main.async {
                        if shiftPressed && panel.panelState.activeTab == .traduction {
                            panel.onSwapTranslation?()
                        } else {
                            panel.switchTab()
                        }
                    }
                    return nil

                case kVK_DownArrow:
                    DispatchQueue.main.async {
                        if panel.panelState.activeTab == .synonymes && !panel.synonyms.isEmpty {
                            panel.panelState.selectedIndex = min(panel.panelState.selectedIndex + 1, panel.synonyms.count - 1)
                        }
                    }
                    return nil

                case kVK_UpArrow:
                    DispatchQueue.main.async {
                        if panel.panelState.activeTab == .synonymes && !panel.synonyms.isEmpty {
                            panel.panelState.selectedIndex = max(panel.panelState.selectedIndex - 1, 0)
                        }
                    }
                    return nil

                case kVK_Return:
                    DispatchQueue.main.async {
                        if panel.panelState.activeTab == .synonymes {
                            if !panel.synonyms.isEmpty && panel.panelState.selectedIndex < panel.synonyms.count {
                                let synonym = panel.synonyms[panel.panelState.selectedIndex]
                                panel.onSelect?(synonym)
                            }
                        } else if panel.panelState.activeTab == .traduction {
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

        let currentSynonyms = self.synonyms
        let capturedOnSelect = self.onSelect
        let capturedOnSelectTranslation = self.onSelectTranslation
        let capturedOnDismiss = self.onDismiss
        let word = self.originalWord
        let shortcut = self.shortcutDisplayString
        let error = self.errorMessage

        let hostingView = NSHostingView(
            rootView: PanelContentView(
                synonyms: currentSynonyms,
                panelState: panelState,
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

        // Cursor overlay on top (transparent to clicks, tracks mouse for cursor changes)
        let overlay = CursorEdgeOverlay(frame: contentView.bounds)
        overlay.autoresizingMask = [.width, .height]
        contentView.addSubview(overlay)
    }

    private func refreshContent() {
        guard let panel = panel else { return }
        setHostingView(on: panel)
    }

    private func computeOrigin(panelSize: NSSize, caretRect: CGRect?) -> NSPoint {
        // Determine anchor point (caret or mouse)
        let anchor: CGRect
        if let caret = caretRect {
            anchor = caret
        } else {
            let mouse = NSEvent.mouseLocation
            anchor = CGRect(x: mouse.x, y: mouse.y, width: 0, height: 16)
        }

        // Find the screen containing the anchor
        let screen = NSScreen.screens.first { $0.frame.contains(anchor.origin) } ?? NSScreen.main
        guard let screen = screen else {
            return NSPoint(x: 100, y: 100)
        }
        let sf = screen.visibleFrame
        let margin: CGFloat = 8
        let gap: CGFloat = 4

        // --- Vertical: prefer below the word, fallback above ---
        // NSScreen coords: Y=0 is bottom of screen, Y increases upward
        // anchor.origin.y = bottom of the caret rect
        // anchor.maxY = top of the caret rect
        var y: CGFloat
        let spaceBelow = anchor.origin.y - sf.minY
        let spaceAbove = sf.maxY - anchor.maxY

        if spaceBelow >= panelSize.height + gap {
            // Place below: panel top edge just under the word bottom
            y = anchor.origin.y - panelSize.height - gap
        } else if spaceAbove >= panelSize.height + gap {
            // Place above: panel bottom edge just over the word top
            y = anchor.maxY + gap
        } else {
            // Not enough space either way: align to bottom of visible screen
            y = sf.minY + margin
        }

        // --- Horizontal: center on anchor, clamp to screen ---
        var x = anchor.midX - panelSize.width / 2

        // Clamp right edge
        if x + panelSize.width > sf.maxX - margin {
            x = sf.maxX - panelSize.width - margin
        }
        // Clamp left edge
        if x < sf.minX + margin {
            x = sf.minX + margin
        }

        // Final vertical clamp
        y = max(sf.minY + margin, min(y, sf.maxY - panelSize.height - margin))

        return NSPoint(x: x, y: y)
    }

    private func measureTextHeight(_ text: String, width: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13)
        let textWidth = max(width - 32, 40)
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(rect.height)
    }

    private func computeHeight() -> CGFloat {
        if errorMessage != nil {
            return 110
        }

        let headerAndTabs: CGFloat = 60
        let footer: CGFloat = 20

        switch panelState.activeTab {
        case .synonymes:
            if synonyms.isEmpty {
                return headerAndTabs + 50 + footer
            }
            let contentHeight = CGFloat(synonyms.count * 28 + 12)
            return headerAndTabs + min(contentHeight, 168) + footer
        case .traduction:
            guard let text = translationResult else {
                return headerAndTabs + 70 + footer
            }
            let currentWidth = panel?.frame.width ?? 240
            let textHeight = measureTextHeight(text, width: currentWidth)
            // direction label (22) + text + padding (20)
            let contentHeight = 22 + textHeight + 20
            let clamped = min(max(contentHeight, 50), 400)
            return headerAndTabs + clamped + footer
        }
    }
}
