/// A protocol defining the contract for a client that interacts with a Large Language Model.
///
/// This abstraction allows the application to be decoupled from a specific LLM provider.
/// Any type conforming to this protocol can be used by the `CodeGenerator` to produce code.
/// It must be `Sendable` to be safely used across actor boundaries.
protocol LlmClient: Sendable {

  /// Generates code by sending a formatted prompt to the LLM.
  ///
  /// This is the core method for any LLM client. It takes the fully-rendered
  /// prompt string, sends it to the provider's API using a specific model,
  /// and returns the generated code as a string.
  ///
  /// - Parameters:
  ///   - prompt: The complete prompt to be sent to the LLM.
  ///   - model: The specific model to use for this generation request (e.g., "gpt-4o-mini").
  /// - Returns: A string containing the raw code output from the LLM.
  /// - Throws: An `AppError.llmError` if the API call fails or returns an error.
  func generateCode(prompt: String, model: String) async throws -> String
}
