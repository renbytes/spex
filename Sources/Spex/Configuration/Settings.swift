import Foundation
import Vapor

/// A struct responsible for managing the application's configuration.
///
/// It loads settings from environment variables, with a `.env` file used as a fallback
/// for local development. This approach is simpler and more idiomatic for many Swift
/// tools than using a complex hierarchical configuration library.
struct Settings {

  // MARK: Properties

  /// The API key for the OpenAI service.
  let openaiApiKey: String?

  /// The base URL for the OpenAI Chat Completions API.
  let openaiApiUrl: String

  /// The default model to use for OpenAI if not specified by the user.
  let openaiDefaultModel: String

  /// The API key for the Google Gemini service.
  let geminiApiKey: String?

  /// The base URL for the Google Gemini API.
  let geminiApiUrl: String

  /// The default model to use for Gemini if not specified by the user.
  let geminiDefaultModel: String

  // MARK: Initialization

  /// Creates a new `Settings` instance by loading configuration from the environment.
  ///
  /// It reads values from the process environment, which Vapor automatically populates
  /// from `.env` files upon application startup. It will throw an error if
  /// required keys (like API keys) are missing.
  ///
  /// - Throws: `AppError.configError` if a required environment variable is not set.
  init() {
    self.openaiApiKey = Environment.get("OPENAI_API_KEY")
    self.openaiApiUrl =
      Environment.get("OPENAI_API_URL") ?? "https://api.openai.com/v1/chat/completions"
    self.openaiDefaultModel = Environment.get("OPENAI_DEFAULT_MODEL") ?? "gpt-4o-mini"

    self.geminiApiKey = Environment.get("GEMINI_API_KEY")
    self.geminiApiUrl =
      Environment.get("GEMINI_API_URL") ?? "https://generativelanguage.googleapis.com/v1beta/models"
    self.geminiDefaultModel = Environment.get("GEMINI_DEFAULT_MODEL") ?? "gemini-2.5-pro"
  }
}
