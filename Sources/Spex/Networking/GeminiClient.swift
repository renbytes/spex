import Foundation

/// A client for interacting with the Google Gemini API.
///
/// This class conforms to the `LlmClient` protocol, providing a concrete implementation
/// for making requests to Google's generative language services. It handles the unique
/// URL structure and JSON payload required by the Gemini API.
final class GeminiClient: LlmClient {

    // MARK: Properties
    
    private let apiKey: String
    private let baseApiUrl: String
    private let urlSession: URLSession

    // MARK: Initialization
    
    /// Creates a new `GeminiClient`.
    /// - Parameter settings: The application settings containing the API key and base URL.
    /// - Parameter urlSession: The URLSession to use for network requests. Defaults to `URLSession.shared`.
    init(settings: Settings, urlSession: URLSession = .shared) throws {
        guard let apiKey = settings.geminiApiKey else {
            throw AppError.configError("GEMINI_API_KEY not found in environment or .env file. It is required for the Gemini provider.")
        }
        self.apiKey = apiKey
        self.baseApiUrl = settings.geminiApiUrl
        self.urlSession = urlSession
    }
    
    // MARK: LlmClient Conformance

    func generateCode(prompt: String, model: String) async throws -> String {
        // Gemini API includes the model in the URL path.
        let urlString = "\(baseApiUrl)/\(model):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw AppError.llmError("Invalid Gemini API URL constructed: \(urlString)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = GeminiRequest(
            contents: [GeminiContent(parts: [GeminiPart(text: prompt)])]
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            throw AppError.llmError("Failed to encode Gemini request body: \(error.localizedDescription)")
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.llmError("Invalid response received from Gemini API.")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            throw AppError.llmError("Gemini API returned non-success status: \(httpResponse.statusCode) - \(errorBody)")
        }
        
        do {
            let responseBody = try JSONDecoder().decode(GeminiResponse.self, from: data)
            guard let content = responseBody.candidates.first?.content.parts.first?.text else {
                throw AppError.llmError("No content received from Gemini.")
            }
            return content
        } catch {
            throw AppError.parsingError("Failed to decode Gemini response: \(error.localizedDescription)")
        }
    }
}

// MARK: - API Data Structures

private struct GeminiRequest: Codable {
    let contents: [GeminiContent]
}

private struct GeminiContent: Codable {
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]
}

private struct GeminiCandidate: Codable {
    let content: GeminiContent
}
