import Foundation
import Vapor

// MARK: - API Data Structures

/// The JSON body sent to the internal gateway.
private struct InternalRequest: Codable {
    let provider: String
    let model: String
    let prompt: String
    let apiKey: String?

    enum CodingKeys: String, CodingKey {
        case provider, model, prompt
        case apiKey = "api_key"
    }
}

/// The JSON response expected from the internal gateway.
private struct InternalResponse: Decodable {
    let content: String
}

// MARK: - Internal Gateway Client

/// A client for interacting with your internal LLM gateway.
///
/// This class conforms to the `LlmClient` protocol and acts as a proxy. It determines
/// the target provider (e.g., "openai", "google") from the model string, attaches
/// the necessary API key, and forwards the request to the local gateway server.
final class InternalClient: LlmClient {

    private let settings: Settings
    private let urlSession: URLSession
    private let gatewayUrl: URL

    /// Creates a new `InternalClient`.
    /// - Parameter settings: The application settings containing API keys.
    /// - Parameter urlSession: The URLSession to use for network requests.
    init(settings: Settings, urlSession: URLSession = .shared) {
        self.settings = settings
        self.urlSession = urlSession
        // The URL for your local Python/Rust gateway
        self.gatewayUrl = URL(string: "http://127.0.0.1:8000/generate")!
    }

    /// Generates code by proxying the request to the internal gateway.
    ///
    /// The model string is expected to be in the format `"provider:model_name"`
    /// (e.g., `"openai:gpt-4o"`). If no provider is specified, it defaults to "google".
    /// - Parameters:
    ///   - prompt: The prompt to send.
    ///   - model: The model string, including the provider prefix.
    /// - Returns: The string response from the LLM.
    /// - Throws: An `AppError` if the request or parsing fails.
    func generateCode(prompt: String, model: String) async throws -> String {
        // 1. Parse the provider and model name from the model string.
        let parts = model.components(separatedBy: ":")
        let providerName = parts.count > 1 ? parts[0] : "google"
        let modelName = parts.count > 1 ? parts[1] : model

        // 2. Attach the appropriate API key based on the provider.
        var apiKey: String?
        if providerName == "openai" {
            apiKey = settings.openaiApiKey
        } else if providerName == "google" {
            apiKey = settings.geminiApiKey
        }
        // Add other providers like Anthropic here if needed.

        // 3. Construct the request to the internal gateway.
        let requestBody = InternalRequest(
            provider: providerName,
            model: modelName,
            prompt: prompt,
            apiKey: apiKey
        )

        var request = URLRequest(url: gatewayUrl)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(requestBody)
        } catch {
            throw AppError.parsingError(
                "Failed to encode internal request: \(error.localizedDescription)")
        }

        // 4. Send the request and handle the response.
        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
            (200...299).contains(httpResponse.statusCode)
        else {
            let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
            throw AppError.llmError("Internal gateway returned an error: \(statusCode) - \(errorBody)")
        }

        do {
            let decoder = JSONDecoder()
            let responseBody = try decoder.decode(InternalResponse.self, from: data)
            return responseBody.content
        } catch {
            throw AppError.parsingError(
                "Failed to decode response from gateway: \(error.localizedDescription)")
        }
    }
}
