import SwiftUI

enum TranslationState {
    case loading
    case success(translated: String, direction: TranslationDirection)
    case error(String)
}

struct TranslationView: View {
    let state: TranslationState
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            switch state {
            case .loading:
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Traduction...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 16)

            case .success(let translated, let direction):
                Text(direction.label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                HStack {
                    Text(translated)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("↩")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accentColor)
                )
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(translated)
                }

            case .error(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            }
        }
        .padding(.bottom, 8)
    }
}
