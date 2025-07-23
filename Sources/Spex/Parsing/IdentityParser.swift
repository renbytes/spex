import Foundation

/// A "pass-through" parser for data that is already in its final, formatted state.
/// This is typically used with `BlockDataSource` where the user provides a pre-formatted
/// sample block in the `spec.toml` file.
struct IdentityParser: DataParser {
    /// This parser does not interpret the string, so it always returns `nil`.
    /// The `DataSource` using this parser will know to use the raw string directly.
    func parse(from rawString: String) -> ParsedSample? {
        return nil
    }
}
