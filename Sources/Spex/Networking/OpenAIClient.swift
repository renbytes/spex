import Foundation

/// A client for interacting with the OpenAI Chat Completions API.
///
/// This class conforms to the `LlmClient` protocol, providing a concrete implementation
/// for making requests to OpenAI's services. It handles the construction of the request
/// body, authentication, and parsing of the response.
final class OpenAIClient: LlmClient {

  // MARK: Properties

  private let apiKey: String
  private let apiURL: URL
  private let urlSession: URLSession

  // MARK: Initialization

  /// Creates a new `OpenAIClient`.
  /// - Parameter settings: The application settings containing the API key and URL.
  /// - Parameter urlSession: The URLSession to use for network requests. Defaults to `URLSession.shared`.
  init(settings: Settings, urlSession: URLSession = .shared) throws {
    guard let apiKey = settings.openaiApiKey else {
      throw AppError.configError(
        "OPENAI_API_KEY not found in environment or .env file. It is required for the OpenAI provider."
      )
    }
    self.apiKey = apiKey
    self.apiURL = URL(string: settings.openaiApiUrl)!
    self.urlSession = urlSession
  }

  // MARK: LlmClient Conformance

  func generateCode(prompt: String, model: String) async throws -> String {
    var request = URLRequest(url: apiURL)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let requestBody = OpenAIRequest(
      model: model,
      messages: [OpenAIMessage(role: "user", content: prompt)]
    )

    do {
      request.httpBody = try JSONEncoder().encode(requestBody)
    } catch {
      throw AppError.llmError("Failed to encode OpenAI request body: \(error.localizedDescription)")
    }

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw AppError.llmError("Invalid response received from OpenAI API.")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      let errorBody = String(data: data, encoding: .utf8) ?? "No error body"
      throw AppError.llmError(
        "OpenAI API returned non-success status: \(httpResponse.statusCode) - \(errorBody)")
    }

    do {
      let responseBody = try JSONDecoder().decode(OpenAIResponse.self, from: data)
      guard let content = responseBody.choices.first?.message.content else {
        throw AppError.llmError("No content received from OpenAI.")
      }
      return content
    } catch {
      throw AppError.parsingError("Failed to decode OpenAI response: \(error.localizedDescription)")
    }
  }
}

// MARK: - API Data Structures

private struct OpenAIRequest: Codable {
  let model: String
  let messages: [OpenAIMessage]
}

private struct OpenAIMessage: Codable {
  let role: String
  let content: String
}

private struct OpenAIResponse: Codable {
  let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Codable {
  let message: OpenAIMessage
}
