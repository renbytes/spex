/// A protocol defining the contract for a client that can connect to a data source
/// to fetch schema information and sample data.
///
/// This abstraction allows the application to support various database types (SQL, NoSQL, etc.)
/// by providing different concrete implementations. It must be `Sendable` to be used
/// safely across actor boundaries.
protocol DataSourceClient: Sendable {
    
    /// Connects to the data source.
    ///
    /// This method should establish and verify the connection to the underlying data source.
    /// - Throws: An `AppError` if the connection fails.
    func connect() async throws
    
    /// Fetches the schema and a small sample of data from a given table or collection.
    ///
    /// The implementation should return a formatted string containing both the column
    /// names/types (schema) and a few sample rows. This combined string provides
    /// essential context for the LLM prompt.
    ///
    /// - Parameter tableName: The name of the table or data entity to inspect.
    /// - Returns: A formatted string containing the schema and sample data.
    /// - Throws: An `AppError` if the query fails.
    func fetchSchemaAndSample(tableName: String) async throws -> String
}
