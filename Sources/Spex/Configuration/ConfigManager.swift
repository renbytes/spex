import Foundation

/// Manages loading configuration files and templates for project generation.
///
/// This component is responsible for reading the contents of template files (like Makefiles,
/// READMEs, and `.gitignore`) from the `configs/` directory embedded within the project.
/// This ensures that generated projects are scaffolded with all necessary boilerplate.
struct ConfigManager {

  // MARK: Properties

  /// The root URL where the configuration templates are stored.
  private let configRoot: URL

  // MARK: Initialization

  /// Creates a new `ConfigManager`.
  ///
  /// It determines the location of the `configs` directory relative to the project's root,
  /// allowing the tool to find its resources reliably.
  ///
  /// - Throws: `AppError.configError` if the project root cannot be determined.
  init() throws {
    self.configRoot = try Self.findProjectRoot().appendingPathComponent("configs")
  }

  // MARK: Private Helpers

  /// A robust helper to find the project root directory by searching upwards for `Package.swift`.
  /// This works reliably for both tests and regular execution.
  /// - Parameter path: The starting file path, defaults to the current file (`#file`).
  /// - Throws: An `AppError.configError` if the root cannot be found.
  /// - Returns: The URL of the project's root directory.
  private static func findProjectRoot(from path: String = #file) throws -> URL {
    let currentFileURL = URL(fileURLWithPath: path)
    var currentURL = currentFileURL

    // Navigate up the directory tree until we find a directory containing "Package.swift"
    while currentURL.pathComponents.count > 1 {
      let potentialRoot = currentURL.deletingLastPathComponent()
      let packageSwiftPath = potentialRoot.appendingPathComponent("Package.swift").path
      if FileManager.default.fileExists(atPath: packageSwiftPath) {
        return potentialRoot
      }
      currentURL = potentialRoot
    }
    throw AppError.configError("Could not locate project root from path \(path).")
  }

  /// A helper function to read the content of a file at a given URL.
  private func readString(from url: URL) throws -> String {
    do {
      return try String(contentsOf: url, encoding: .utf8)
    } catch {
      throw AppError.fileReadError(
        "Failed to read template at '\(url.path)': \(error.localizedDescription)")
    }
  }

  // MARK: Public Methods

  /// Gets the content of the shared `.gitignore` template.
  /// - Throws: `AppError.fileReadError` if the template cannot be read.
  func getGitignore() throws -> String {
    let path = configRoot.appendingPathComponent("shared/gitignore.template")
    return try readString(from: path)
  }

  /// Gets the content of the shared `README.md` template.
  /// - Throws: `AppError.fileReadError` if the template cannot be read.
  func getReadmeTemplate() throws -> String {
    let path = configRoot.appendingPathComponent("shared/README.md.template")
    return try readString(from: path)
  }

  /// Gets a specific README instruction snippet for a given language.
  /// - Parameters:
  ///   - language: The target language (e.g., "python").
  ///   - instructionType: The type of instruction, "setup" or "run".
  /// - Returns: The content of the instruction file, or an empty string if not found.
  func getReadmeInstructions(language: String, instructionType: String) -> String {
    if language.lowercased() == "sql" && instructionType == "setup" {
      return ""  // SQL setup is part of the run instructions.
    }

    let path = configRoot.appendingPathComponent(
      "\(language.lowercased())/instructions_\(instructionType).md")
    return (try? readString(from: path)) ?? ""
  }

  /// Gets the content of the `Makefile` template for a given language.
  /// - Throws: `AppError.fileReadError` if the template cannot be read.
  func getMakefile(for language: String) throws -> String {
    let path = configRoot.appendingPathComponent("\(language.lowercased())/Makefile.template")
    return try readString(from: path)
  }

  /// Gets the content of the `pyproject.toml` file for a given language, if it exists.
  func getPyprojectToml(for language: String) -> String? {
    let path = configRoot.appendingPathComponent("\(language.lowercased())/pyproject.toml")
    return try? readString(from: path)
  }

  /// Gets the content of the `environment.yml` file for a given language, if it exists.
  func getEnvironmentYml(for language: String) -> String? {
    let path = configRoot.appendingPathComponent("\(language.lowercased())/environment.yml")
    return try? readString(from: path)
  }
}
