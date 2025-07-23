import Foundation
import Rainbow

/// An enum to represent different types of log messages.
enum LogType {
  case info
  case success
  case warning
  case error
}

/// A simple utility for printing colored messages to the console.
/// This centralizes the logic for styling command-line output, ensuring
/// a consistent look and feel for all user-facing messages.
struct Logger {

  /// Prints a message to the console with a specific color and prefix based on its type.
  ///
  /// - Parameters:
  ///   - message: The string to print.
  ///   - type: The type of the log message, which determines the color and prefix.
  static func log(_ message: String, type: LogType) {
    switch type {
    case .info:
      // Use yellow for general informational messages.
      print(message.yellow)
    case .success:
      // Use bold green for success messages.
      print("✅ Success: ".green.bold + message.green)
    case .warning:
      // Use magenta for warnings that aren't critical errors.
      print("⚠️ Warning: ".magenta.bold + message.magenta)
    case .error:
      // Use bold red for critical errors to make them stand out.
      print("❌ Error: ".red.bold + message.red)
    }
  }
}
