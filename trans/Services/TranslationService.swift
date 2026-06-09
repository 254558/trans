import Foundation

// MARK: - API Response Types

struct DeepSeekChatResponse: Codable {
    let id: String
    let choices: [Choice]
}

struct Choice: Codable {
    let index: Int
    let message: Message
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct Message: Codable {
    let role: String
    let content: String
}

// MARK: - Errors

enum TranslationError: LocalizedError {
    case missingAPIKey
    case apiError(String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "请在设置中输入 DeepSeek API Key"
        case .apiError(let msg): return "API 错误: \(msg)"
        case .emptyResponse: return "返回结果为空"
        }
    }
}

// MARK: - Translation Service

actor TranslationService {
    static let shared = TranslationService()

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    func translate(_ text: String) async throws -> TranslationResult {
        let apiKey = try AppConfig.apiKey

        let url = URL(string: "https://api.deepseek.com/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text]
            ],
            "temperature": 0.1,
            "response_format": ["type": "json_object"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranslationError.apiError("无响应")
        }
        guard httpResponse.statusCode == 200 else {
            let bodyText = String(data: data, encoding: .utf8) ?? ""
            throw TranslationError.apiError("HTTP \(httpResponse.statusCode): \(bodyText)")
        }

        let apiResponse = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = apiResponse.choices.first?.message.content else {
            throw TranslationError.emptyResponse
        }

        guard let contentData = content.data(using: .utf8),
              let result = try? JSONDecoder().decode(TranslationResult.self, from: contentData) else {
            return TranslationResult(
                original: text, translation: content,
                sourceLanguage: detectLanguage(text), targetLanguage: targetLangCode(for: text)
            )
        }

        return TranslationResult(
            original: text,
            translation: result.translation,
            sourceLanguage: result.sourceLanguage.isEmpty ? detectLanguage(text) : result.sourceLanguage,
            targetLanguage: result.targetLanguage.isEmpty ? targetLangCode(for: text) : result.targetLanguage
        )
    }

    // MARK: - Private

    private let systemPrompt = """
你是一个只会说大白话的日常口语翻译工具，严格遵守以下所有强制规则，绝对不能违反：
1. 只做日常普通人聊天的极简口语翻译，拒绝任何书面语、正式语、专业词汇、复杂句式
2. 中文译英文：只用小学最简单英文单词、最短句子，老外日常聊天随口说的话，不要高级语法、不要长句
3. 英文译中文：只用大白话、日常口语、接地气，不用成语、不用书面词、不用文雅表达
4. 坚决精简：能短就短，删掉所有冗余修饰，只保留最核心意思
5. 禁止任何解释、补充、备注、格式化，只输出翻译结果
6. 杜绝机器翻译感、杜绝学术感、杜绝商务正式感

请严格按照以下 JSON 格式返回，不要包含 markdown 标记：
{
  "translation": "翻译结果",
  "source_language": "en|zh",
  "target_language": "zh|en"
}
"""

    private func targetLangCode(for text: String) -> String {
        let cjk = text.unicodeScalars.filter { $0.properties.isIdeographic }.count
        return Double(cjk) / Double(max(text.count, 1)) > 0.3 ? "en" : "zh"
    }

    private func detectLanguage(_ text: String) -> String {
        let cjk = text.unicodeScalars.filter { $0.properties.isIdeographic }.count
        let ratio = Double(cjk) / Double(max(text.count, 1))
        if ratio > 0.3 {
            let jp = text.unicodeScalars.filter {
                (0x3040...0x30FF).contains($0.value) || (0xFF66...0xFF9F).contains($0.value)
            }.count
            return Double(jp) / Double(max(text.count, 1)) > 0.1 ? "ja" : "zh"
        }
        return "en"
    }
}
