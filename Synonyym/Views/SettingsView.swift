import SwiftUI
import AppKit
import Carbon.HIToolbox

// MARK: - ShortcutConfig

struct ShortcutConfig {
    var keyCode: UInt32
    var modifiers: UInt32

    static let defaultKeyCode = UInt32(kVK_ANSI_S)
    static let defaultModifiers = UInt32(cmdKey | shiftKey)

    static let keyCodeKey = "shortcutKeyCode"
    static let modifiersKey = "shortcutModifiers"

    static func load() -> ShortcutConfig {
        let defaults = UserDefaults.standard
        let hasCustom = defaults.object(forKey: keyCodeKey) != nil
        if hasCustom {
            return ShortcutConfig(
                keyCode: UInt32(defaults.integer(forKey: keyCodeKey)),
                modifiers: UInt32(defaults.integer(forKey: modifiersKey))
            )
        }
        return ShortcutConfig(keyCode: defaultKeyCode, modifiers: defaultModifiers)
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: ShortcutConfig.keyCodeKey)
        defaults.set(Int(modifiers), forKey: ShortcutConfig.modifiersKey)
    }

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

// MARK: - KeyCode to String

func keyCodeToString(_ keyCode: UInt32) -> String {
    switch Int(keyCode) {
    // Letters
    case kVK_ANSI_A: return "A"
    case kVK_ANSI_B: return "B"
    case kVK_ANSI_C: return "C"
    case kVK_ANSI_D: return "D"
    case kVK_ANSI_E: return "E"
    case kVK_ANSI_F: return "F"
    case kVK_ANSI_G: return "G"
    case kVK_ANSI_H: return "H"
    case kVK_ANSI_I: return "I"
    case kVK_ANSI_J: return "J"
    case kVK_ANSI_K: return "K"
    case kVK_ANSI_L: return "L"
    case kVK_ANSI_M: return "M"
    case kVK_ANSI_N: return "N"
    case kVK_ANSI_O: return "O"
    case kVK_ANSI_P: return "P"
    case kVK_ANSI_Q: return "Q"
    case kVK_ANSI_R: return "R"
    case kVK_ANSI_S: return "S"
    case kVK_ANSI_T: return "T"
    case kVK_ANSI_U: return "U"
    case kVK_ANSI_V: return "V"
    case kVK_ANSI_W: return "W"
    case kVK_ANSI_X: return "X"
    case kVK_ANSI_Y: return "Y"
    case kVK_ANSI_Z: return "Z"
    // Numbers
    case kVK_ANSI_0: return "0"
    case kVK_ANSI_1: return "1"
    case kVK_ANSI_2: return "2"
    case kVK_ANSI_3: return "3"
    case kVK_ANSI_4: return "4"
    case kVK_ANSI_5: return "5"
    case kVK_ANSI_6: return "6"
    case kVK_ANSI_7: return "7"
    case kVK_ANSI_8: return "8"
    case kVK_ANSI_9: return "9"
    // Function keys
    case kVK_F1: return "F1"
    case kVK_F2: return "F2"
    case kVK_F3: return "F3"
    case kVK_F4: return "F4"
    case kVK_F5: return "F5"
    case kVK_F6: return "F6"
    case kVK_F7: return "F7"
    case kVK_F8: return "F8"
    case kVK_F9: return "F9"
    case kVK_F10: return "F10"
    case kVK_F11: return "F11"
    case kVK_F12: return "F12"
    // Special keys
    case kVK_Space: return "␣"
    case kVK_Return: return "↩"
    case kVK_Tab: return "⇥"
    case kVK_Delete: return "⌫"
    case kVK_ForwardDelete: return "⌦"
    case kVK_Escape: return "⎋"
    // Arrows
    case kVK_LeftArrow: return "←"
    case kVK_RightArrow: return "→"
    case kVK_UpArrow: return "↑"
    case kVK_DownArrow: return "↓"
    // Punctuation
    case kVK_ANSI_Minus: return "-"
    case kVK_ANSI_Equal: return "="
    case kVK_ANSI_LeftBracket: return "["
    case kVK_ANSI_RightBracket: return "]"
    case kVK_ANSI_Backslash: return "\\"
    case kVK_ANSI_Semicolon: return ";"
    case kVK_ANSI_Quote: return "'"
    case kVK_ANSI_Comma: return ","
    case kVK_ANSI_Period: return "."
    case kVK_ANSI_Slash: return "/"
    case kVK_ANSI_Grave: return "`"
    default: return "?"
    }
}

// MARK: - Carbon modifier flags from NSEvent

func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var carbon: UInt32 = 0
    if flags.contains(.command) { carbon |= UInt32(cmdKey) }
    if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
    if flags.contains(.option) { carbon |= UInt32(optionKey) }
    if flags.contains(.control) { carbon |= UInt32(controlKey) }
    return carbon
}

// MARK: - SettingsView

struct SettingsView: View {
    let currentConfig: ShortcutConfig
    let onShortcutChanged: (UInt32, UInt32) -> Void

    @State private var isRecording = false
    @State private var displayString: String

    init(currentConfig: ShortcutConfig, onShortcutChanged: @escaping (UInt32, UInt32) -> Void) {
        self.currentConfig = currentConfig
        self.onShortcutChanged = onShortcutChanged
        _displayString = State(initialValue: currentConfig.displayString)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Réglages")
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Text("Raccourci :")
                    .frame(width: 80, alignment: .trailing)

                ShortcutRecorderView(
                    displayString: $displayString,
                    isRecording: $isRecording,
                    onShortcutCaptured: { keyCode, modifiers in
                        onShortcutChanged(keyCode, modifiers)
                    }
                )
                .frame(width: 140, height: 28)

                Button("Réinitialiser") {
                    let def = ShortcutConfig(
                        keyCode: ShortcutConfig.defaultKeyCode,
                        modifiers: ShortcutConfig.defaultModifiers
                    )
                    displayString = def.displayString
                    onShortcutChanged(def.keyCode, def.modifiers)
                }
                .controlSize(.small)
            }

            if isRecording {
                Text("Appuyez sur la nouvelle combinaison de touches...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(24)
        .frame(width: 400, height: 160)
    }
}

// MARK: - ShortcutRecorderView

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var displayString: String
    @Binding var isRecording: Bool
    let onShortcutCaptured: (UInt32, UInt32) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.displayString = displayString
        view.isRecording = isRecording
        view.onRecordingChanged = { recording in
            DispatchQueue.main.async { isRecording = recording }
        }
        view.onShortcutCaptured = { keyCode, modifiers in
            let config = ShortcutConfig(keyCode: keyCode, modifiers: modifiers)
            DispatchQueue.main.async {
                displayString = config.displayString
                isRecording = false
            }
            onShortcutCaptured(keyCode, modifiers)
        }
        return view
    }

    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.displayString = displayString
        nsView.isRecording = isRecording
        nsView.needsDisplay = true
    }
}

// MARK: - ShortcutRecorderNSView

class ShortcutRecorderNSView: NSView {
    var displayString: String = ""
    var isRecording: Bool = false
    var onRecordingChanged: ((Bool) -> Void)?
    var onShortcutCaptured: ((UInt32, UInt32) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            isRecording = true
            onRecordingChanged?(true)
            window?.makeFirstResponder(self)
            needsDisplay = true
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        // Ignore lone modifier presses or Escape to cancel
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            onRecordingChanged?(false)
            needsDisplay = true
            return
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)

        // Require at least Cmd or Ctrl
        let hasRequiredModifier = (modifiers & UInt32(cmdKey) != 0) || (modifiers & UInt32(controlKey) != 0)
        guard hasRequiredModifier else { return }

        let keyCode = UInt32(event.keyCode)
        isRecording = false
        onRecordingChanged?(false)
        onShortcutCaptured?(keyCode, modifiers)
        needsDisplay = true
    }

    override func flagsChanged(with event: NSEvent) {
        // Don't process lone modifier keys
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            onRecordingChanged?(false)
            needsDisplay = true
        }
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        // Background
        if isRecording {
            NSColor.controlAccentColor.withAlphaComponent(0.1).setFill()
        } else if isHovered {
            NSColor.controlBackgroundColor.setFill()
        } else {
            NSColor.controlBackgroundColor.setFill()
        }
        path.fill()

        // Border
        if isRecording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 2
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
        }
        path.stroke()

        // Text
        let text = isRecording ? "Enregistrement..." : displayString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: isRecording ? NSColor.controlAccentColor : NSColor.labelColor,
        ]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let textSize = attrStr.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attrStr.draw(in: textRect)
    }
}
