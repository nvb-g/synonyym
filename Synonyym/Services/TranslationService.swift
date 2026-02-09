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

        var components = URLComponents(string: "https://api.mymemory.translated.net/get")!
        components.queryItems = [
            URLQueryItem(name: "q", value: word),
            URLQueryItem(name: "langpair", value: langPair)
        ]

        guard let url = components.url else {
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

            // Decode any percent-encoded characters the API may return
            let decoded = translatedText.removingPercentEncoding ?? translatedText

            DispatchQueue.main.async {
                completion(.success(translated: decoded.lowercased(), direction: direction))
            }
        }.resume()
    }
}
