import Foundation

struct TranslationResult: Codable {
    let original: String
    let translation: String
    let sourceLanguage: String
    let targetLanguage: String

    enum CodingKeys: String, CodingKey {
        case translation
        case sourceLanguage = "source_language"
        case targetLanguage = "target_language"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.translation = try container.decode(String.self, forKey: .translation)
        self.sourceLanguage = try container.decodeIfPresent(String.self, forKey: .sourceLanguage) ?? ""
        self.targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage) ?? ""
        self.original = ""
    }

    init(original: String, translation: String, sourceLanguage: String = "",
         targetLanguage: String = "") {
        self.original = original
        self.translation = translation
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}
