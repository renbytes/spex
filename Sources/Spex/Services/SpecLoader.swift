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
            let spec = try TOMLDecoder().decode(Specification.self, from: fileContent)

            // Validate that datasets have actual data sources
            for dataset in spec.datasets {
                if dataset.sampleDataPath == nil && dataset.sampleDataBlock == nil {
                    throw AppError.validationError(
                        """

                        It looks like your spec.toml is missing sample data for dataset '\(dataset.name)'.

                        Please edit '\(path)' and either:
                        1. Add a sample_data_path pointing to a CSV file, or
                        2. Add a sample_data_block with inline sample data

                        Example:
                        [[dataset]]
                        name = "\(dataset.name)"
                        description = "\(dataset.description)"
                        sample_data_block = \"\"\"
                        user_id,event_type,page_id,timestamp
                        user_001,click,home_page,2025-01-15T10:00:00Z
                        user_002,impression,product_page,2025-01-15T10:01:00Z
                        \"\"\"
                        """
                    )
                }
            }

            // Also check output datasets if they exist
            if let outputDatasets = spec.outputDatasets {
                for dataset in outputDatasets {
                    if dataset.sampleDataPath == nil && dataset.sampleDataBlock == nil {
                        throw AppError.validationError(
                            """

                            Missing sample data for output dataset '\(dataset.name)'.

                            While output samples are optional, providing them greatly improves the quality of generated code.
                            Please edit '\(path)' and add a sample_data_block showing expected output format.
                            """
                        )
                    }
                }
            }

            return spec
        } catch let error as AppError {
            // Re-throw AppErrors as-is
            throw error
        } catch {
            // Check if this is likely a case of commented-out fields
            if fileContent.contains("# sample_data_path") || fileContent.contains("# sample_data_block") {
                throw AppError.validationError(
                    """

                    Your spec.toml has commented-out sample data fields.
                    Please edit '\(path)' and uncomment either sample_data_path or sample_data_block for each dataset.

                    Quick tip: Remove the '#' and fill in actual data:
                    sample_data_block = \"\"\"
                    column1,column2,column3
                    value1,value2,value3
                    \"\"\"
                    """
                )
            }

            // Provide a more detailed error message for TOML parsing issues.
            let detailedError = "Failed to parse TOML from '\(path)': \(error.localizedDescription)"
            throw AppError.parsingError(detailedError)
        }
    }
}
