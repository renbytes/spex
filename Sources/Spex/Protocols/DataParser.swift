import Foundation

/// A type alias for the structured data returned by a parser.
typealias ParsedSample = (header: [String], rows: [[String]])

/// Defines the contract for a component that can parse a raw string into structured data.
/// This decouples the parsing logic from how the data was acquired.
protocol DataParser {
    /// Parses a raw string into a header and an array of rows.
    ///
    /// - Parameter rawString: The raw string content to be parsed.
    /// - Returns: A `ParsedSample` tuple containing the header and rows, or `nil` if parsing fails.
    func parse(from rawString: String) -> ParsedSample?
}
