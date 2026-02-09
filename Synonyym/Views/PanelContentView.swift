import SwiftUI

enum PanelTab: String, CaseIterable {
    case synonymes = "Synonymes"
    case traduction = "Traduction"
}

struct PanelContentView: View {
    let synonyms: [Synonym]
    @Binding var selectedIndex: Int
    @Binding var activeTab: PanelTab
    let translationState: TranslationState
    let onSelect: (Synonym) -> Void
    let onSelectTranslation: (String) -> Void
    let onDismiss: () -> Void
    let originalWord: String
    var shortcutDisplayString: String = "⌘⇧S"
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(originalWord)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(shortcutDisplayString)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 6)

            // Tab bar (only shown when no error)
            if errorMessage == nil {
                HStack(spacing: 0) {
                    ForEach(PanelTab.allCases, id: \.self) { tab in
                        Button {
                            activeTab = tab
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: activeTab == tab ? .semibold : .regular))
                                .foregroundStyle(activeTab == tab ? .primary : .secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(activeTab == tab ? Color.primary.opacity(0.08) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }

            Divider()
                .padding(.horizontal, 8)

            // Content
            if let errorMessage = errorMessage {
                errorContent(errorMessage)
            } else {
                switch activeTab {
                case .synonymes:
                    synonymsContent
                case .traduction:
                    TranslationView(state: translationState) { translated in
                        onSelectTranslation(translated)
                    }
                }
            }

            // Footer hints
            if errorMessage == nil {
                footerHints
            }
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: - Synonyms content

    @ViewBuilder
    private var synonymsContent: some View {
        if synonyms.isEmpty {
            Text("Aucun synonyme trouvé")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 2) {
                        ForEach(Array(synonyms.enumerated()), id: \.element.id) { index, synonym in
                            SynonymRow(
                                synonym: synonym,
                                isSelected: index == selectedIndex
                            )
                            .id(index)
                            .onTapGesture {
                                onSelect(synonym)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 6)
                }
                .frame(maxHeight: 160)
                .onChange(of: selectedIndex) { _, newValue in
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    // MARK: - Error content

    @ViewBuilder
    private func errorContent(_ message: String) -> some View {
        VStack(spacing: 6) {
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Ouvrir Réglages") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .buttonStyle(.link)
            .font(.system(size: 12))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
    }

    // MARK: - Footer hints

    private var footerHints: some View {
        HStack(spacing: 4) {
            if activeTab == .synonymes && !synonyms.isEmpty {
                Text("↑↓")
            }
            Text("Tab")
            if activeTab == .synonymes && !synonyms.isEmpty {
                Text("↩")
            } else if case .success = translationState, activeTab == .traduction {
                Text("↩")
            }
            Text("Esc")
        }
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(.quaternary)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 6)
        .padding(.top, 2)
    }
}
