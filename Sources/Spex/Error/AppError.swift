import Foundation

/// The primary error type for the Spex application.
///
/// Each case represents a specific category of error that can occur. Conforming to
/// `LocalizedError` allows for providing user-friendly descriptions for each error,
/// which is useful for command-line output.
enum AppError: Error, LocalizedError {

    /// Represents an error during the configuration loading process.
    case configError(String)

    /// Represents an error related to invalid user input from the CLI.
    case inputError(String)

    /// Represents a validation error in the user's spec file.
    case validationError(String)

    /// Represents an error that occurs while trying to read a file from disk.
    case fileReadError(String)

    /// Represents an error that occurs while trying to write a file to disk.
    case fileWriteError(path: String, source: Error)

    /// Represents an error from the Language Model (LLM) client (e.g., network or API error).
    case llmError(String)

    /// Represents an error during the prompt template rendering process.
    case templateError(String)

    /// Represents an error when parsing data, such as TOML or the LLM's output.
    case parsingError(String)

    /// Provides a human-readable description for each error case.
    var errorDescription: String? {
        switch self {
        case .configError(let message):
            return "Configuration error: \(message)"
        case .inputError(let message):
            return "Invalid input: \(message)"
        case .validationError(let message):
            return "Validation error in spec file: \(message)"
        case .fileReadError(let message):
            return "Failed to read file: \(message)"
        case .fileWriteError(let path, let source):
            return "Failed to write to path '\(path)': \(source.localizedDescription)"
        case .llmError(let message):
            return "LLM client error: \(message)"
        case .templateError(let message):
            return "Template rendering error: \(message)"
        case .parsingError(let message):
            return "Failed to parse data: \(message)"
        }
    }
}
