import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("À propos de Synonyym") {
                showAbout()
            }
            .keyboardShortcut("i", modifiers: .command)

            Button("Réglages...") {
                appState.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            if !appState.hasAccessibilityPermission {
                Button("Activer l'Accessibilité...") {
                    openAccessibilitySettings()
                }
                .foregroundStyle(.red)

                Divider()
            }

            Button("Quitter Synonyym") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }

    private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Synonyym"
        alert.informativeText = """
        Micro-outil macOS de synonymes français.

        Utilisez \(appState.shortcutDisplayString) pour remplacer un mot par un synonyme.

        Thesaurus : LibreOffice (LGPL 2.1+)
        36 000+ mots · 100% hors-ligne
        Aucune API · Aucune limite d'appels

        Version 1.0
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}
