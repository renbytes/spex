import Foundation
import TOMLKit

/// A service responsible for loading and parsing a `spec.toml` file.
///
/// This component isolates the file I/O and parsing logic, decoupling the main
/// `Specification` model from the details of how it is loaded from disk.
struct SpecLoader {

    /// Loads a `Specification` from a given file path.
    ///
    /// This function performs two main tasks:
    /// 1. Reads the content of the file at the specified path.
    /// 2. Uses `TOMLDecoder` to parse the string content into a `Specification` object.
    ///
    /// - Parameter path: The absolute or relative path to the `spec.toml` file.
    /// - Throws:
    ///   - `AppError.fileReadError` if the file cannot be read.
    ///   - `AppError.parsingError` if the TOML content is invalid.
    /// - Returns: A decoded `Specification` instance.
    func load(from path: String) throws -> Specification {
        let specURL = URL(fileURLWithPath: path)
        let fileContent: String
        do {
            fileContent = try String(contentsOf: specURL, encoding: .utf8)
        } catch {
            throw AppError.fileReadError("Could not read spec file at '\(path)': \(error.localizedDescription)")
        }

        do {
            return try TOMLDecoder().decode(Specification.self, from: fileContent)
        } catch {
            // Provide a more detailed error message for TOML parsing issues.
            let detailedError = "Failed to parse TOML from '\(path)': \(error.localizedDescription)"
            throw AppError.parsingError(detailedError)
        }
    }
}
