import AppKit
import CoreGraphics
import Carbon.HIToolbox
import ApplicationServices

final class TextInteractor {

    /// Get the screen position of the text caret using Accessibility API.
    /// Returns the rect of the selected text/caret in NSScreen coordinates (bottom-left origin).
    func getCaretRect() -> CGRect? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success else {
            return nil
        }
        guard let focusedEl = focusedElement else { return nil }
        let element = focusedEl as! AXUIElement

        // Get selected text range
        var rangeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
              let range = rangeValue else {
            return nil
        }

        // Get bounds for that range
        var boundsValue: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXBoundsForRangeParameterizedAttribute as CFString, range, &boundsValue) == .success else {
            return nil
        }

        var axRect = CGRect.zero
        guard let boundsVal = boundsValue else { return nil }
        AXValueGetValue(boundsVal as! AXValue, .cgRect, &axRect)

        // AX coordinates: origin at top-left of main screen, Y goes down
        // NSScreen coordinates: origin at bottom-left, Y goes up
        guard let screenHeight = NSScreen.main?.frame.height else { return nil }
        let nsRect = CGRect(
            x: axRect.origin.x,
            y: screenHeight - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
        return nsRect
    }

    /// Read the currently selected text via Accessibility API (no clipboard needed).
    func getSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let focusedEl = focusedElement else {
            return nil
        }
        let element = focusedEl as! AXUIElement

        var selectedText: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &selectedText) == .success,
              let text = selectedText as? String,
              !text.isEmpty else {
            return nil
        }
        return text
    }

    /// Select the word before the cursor: simulate Option+Shift+Left Arrow
    func selectWordBeforeCursor() {
        simulateKeyPress(
            keyCode: UInt16(kVK_LeftArrow),
            flags: [.maskAlternate, .maskShift]
        )
    }

    /// Copy selected text: simulate Cmd+C
    func copySelection() {
        simulateKeyPress(
            keyCode: UInt16(kVK_ANSI_C),
            flags: [.maskCommand]
        )
    }

    /// Paste from clipboard: simulate Cmd+V
    func pasteFromClipboard() {
        simulateKeyPress(
            keyCode: UInt16(kVK_ANSI_V),
            flags: [.maskCommand]
        )
    }

    /// Deselect text: simulate Right Arrow
    func deselectText() {
        simulateKeyPress(
            keyCode: UInt16(kVK_RightArrow),
            flags: []
        )
    }

    private func simulateKeyPress(keyCode: UInt16, flags: CGEventFlags) {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }

        keyDown.flags = flags
        keyUp.flags = flags

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
