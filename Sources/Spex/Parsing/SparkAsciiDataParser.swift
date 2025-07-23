import Foundation

/// A parser for interpreting strings formatted as ASCII tables (e.g., from Spark).
///
/// This component is designed to handle text that is structured with pipes (`|`) and pluses (`+`)
/// to create a visual table, a common output format for command-line database tools and
/// Spark's `show()` method.
///
/// ### Example Input
/// The `rawString` parameter is expected to look like this:
/// ```text
/// +-------+---+----------------+
/// | name  |age| role           |
/// +-------+---+----------------+
/// | Alice | 42| Data Scientist |
/// | Bob   | 35| Engineer       |
/// +-------+---+----------------+
/// ```
struct SparkAsciiDataParser: DataParser {
    func parse(from rawString: String) -> ParsedSample? {
        let lines = rawString.split(separator: "\n")
        
        // Isolate only the lines that contain table data, ignoring the decorative lines like "+---+---+"
        let tableLines = lines.filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("|") }

        guard !tableLines.isEmpty else { return nil }

        // Helper to split a single line (e.g., "| Alice | 29 |") into an array of cell values (e.g., ["Alice", "29"])
        let extractCells = { (line: Substring) -> [String] in
            return line.split(separator: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty } // Removes empty strings that result from the leading and trailing pipes
        }

        let header = extractCells(tableLines[0])
        let rows = tableLines.dropFirst().map(extractCells)

        if header.isEmpty { return nil }
        
        return (header, rows)
    }
}