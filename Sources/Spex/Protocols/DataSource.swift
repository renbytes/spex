import Foundation

/// A protocol defining the contract for a client that can fetch schema
/// information and sample data from a data source.
protocol DataSource {
    /// Fetches the schema and a small sample of data for a given dataset.
    /// - Parameter dataset: The `Dataset` instance to inspect.
    /// - Returns: A formatted string containing both the schema and sample data for the LLM.
    /// - Throws: An `AppError` if the data source cannot be accessed or parsed.
    func fetchSchemaAndSample(for dataset: Dataset) async throws -> String
}
