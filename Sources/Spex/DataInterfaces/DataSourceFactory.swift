import Foundation

/// A factory that composes and creates the appropriate `DataSource` instance
/// by injecting the correct `DataParser`.
struct DataSourceFactory {

    /// Creates and returns a `DataSource` based on the provided dataset's properties.
    ///
    /// This acts as the composition root for our data handling logic. It first determines
    /// which data source to use (e.g., from a file or an inline block). Then, if necessary,
    /// it determines which parser to use (e.g., CSV or delimited text) and injects
    /// it into the data source instance.
    ///
    /// - Parameter dataset: The `Dataset` instance to inspect.
    /// - Returns: An instance conforming to `DataSource`, or `nil` if no valid source is specified.
    static func makeDataSource(for dataset: Dataset) -> (any DataSource)? {
        // Case 1: The data is located in a file specified by `sampleDataPath`.
        if let path = dataset.sampleDataPath {
            let parser: DataParser
            
            // Determine which parser to use based on the file extension.
            if path.lowercased().hasSuffix(".csv") {
                parser = CsvDataParser()
            } else {
                // Default to the delimited text parser for other file types like .txt.
                // This logic could be expanded to check a `format` field in the spec.
                parser = DelimitedDataParser()
            }
            // Return a file-based data source with the appropriate parser injected.
            return LocalFileDataSource(parser: parser)

        // Case 2: The data is provided as an inline block in the spec file.
        } else if dataset.sampleDataBlock != nil {
            // Inline blocks are assumed to be pre-formatted and do not need parsing.
            // We use the simple BlockDataSource which returns the content directly.
            return BlockDataSource()
            
        // Case 3: No data source is specified.
        } else {
            return nil
        }
    }
}