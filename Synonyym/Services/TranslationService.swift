import Foundation

enum TranslationDirection {
    case frToEn
    case enToFr

    var label: String {
        switch self {
        case .frToEn: return "FR → EN"
        case .enToFr: return "EN → FR"
        }
    }
}

enum TranslationResult {
    case success(translated: String, direction: TranslationDirection)
    case error(String)
}

final class TranslationService {
    func translate(word: String, isFrench: Bool, completion: @escaping (TranslationResult) -> Void) {
        let direction: TranslationDirection = isFrench ? .frToEn : .enToFr
        let langPair = isFrench ? "fr|en" : "en|fr"

        guard let encoded = word.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.mymemory.translated.net/get?q=\(encoded)&langpair=\(langPair)") else {
            DispatchQueue.main.async {
                completion(.error("URL invalide"))
            }
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.error("Traduction indisponible"))
                }
                slog("translation error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseData = json["responseData"] as? [String: Any],
                  let translatedText = responseData["translatedText"] as? String,
                  !translatedText.isEmpty else {
                DispatchQueue.main.async {
                    completion(.error("Traduction indisponible"))
                }
                return
            }

            DispatchQueue.main.async {
                completion(.success(translated: translatedText.lowercased(), direction: direction))
            }
        }.resume()
    }
}
