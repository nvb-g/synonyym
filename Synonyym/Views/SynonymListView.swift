import SwiftUI
import AppKit

struct SynonymListView: View {
    let synonyms: [Synonym]
    @Binding var selectedIndex: Int
    let onSelect: (Synonym) -> Void
    let onDismiss: () -> Void
    let originalWord: String
    var shortcutDisplayString: String = "⌘⇧S"
    var errorMessage: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header showing the original word
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

            Divider()
                .padding(.horizontal, 8)

            if let errorMessage = errorMessage {
                VStack(spacing: 6) {
                    Text(errorMessage)
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
            } else if synonyms.isEmpty {
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
                    .frame(maxHeight: 180)
                    .onAppear {
                        proxy.scrollTo(selectedIndex, anchor: .center)
                    }
                }
            }
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }
}

struct SynonymRow: View {
    let synonym: Synonym
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(synonym.word)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white : .primary)
            Spacer()
            if isSelected {
                Text("↩")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
