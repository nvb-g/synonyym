import SwiftUI

enum TranslationState {
    case loading
    case success(translated: String, direction: TranslationDirection)
    case error(String)
}

// MARK: - Inline translation (inside the panel)

struct TranslationView: View {
    let state: TranslationState
    let onSelect: (String) -> Void

    var body: some View {
        switch state {
        case .loading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Traduction...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

        case .success(let translated, let direction):
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Text(direction.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("⇧Tab inverser")
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

                ScrollView(.vertical, showsIndicators: true) {
                    Text(translated)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                )
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(translated)
                }
            }
            .frame(maxHeight: .infinity)

        case .error(let message):
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
