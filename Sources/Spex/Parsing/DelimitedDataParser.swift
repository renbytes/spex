import Foundation

/// A parser for interpreting strings where columns are separated by one or more whitespace characters.
///
/// This component is designed to handle text that is structured with space or tab delimiters.
/// It intelligently handles cases where the first column itself may contain spaces (e.g., a timestamp).
///
/// ### Example Input
/// The `rawString` parameter is expected to look like this:
/// ```text
/// snapped_at              price   market_cap    total_volume
/// 2013-12-27 00:00:00 UTC 734.27  8944473292.0    62881800.0
/// 2013-12-28 00:00:00 UTC 738.81  9002769255.0    28121600.0
/// ```
struct DelimitedDataParser: DataParser {

    /// Parses a string containing a whitespace-delimited table into a header and rows.
    ///
    /// - Parameter rawString: A string that may contain whitespace-delimited data.
    /// - Returns: A `ParsedSample` tuple containing the `header` and `rows`, or `nil` if parsing fails.
    func parse(from rawString: String) -> ParsedSample? {
        let lines = rawString.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Must have at least a header and one row of data.
        guard lines.count > 1 else { return nil }

        // Helper to split a line by any whitespace.
        let splitByWhitespace = { (line: String) -> [String] in
            return line.split(whereSeparator: \.isWhitespace).map(String.init)
        }

        let header = splitByWhitespace(lines.first!)
        let columnCount = header.count
        
        // Must have more than one column to be a valid table.
        guard columnCount > 1 else { return nil }

        var parsedRows: [[String]] = []

        for line in lines.dropFirst() {
            let components = splitByWhitespace(line)
            guard components.count >= columnCount else { return nil } // Row must have at least enough components.

            // Assume the last (N-1) components map to the last (N-1) headers.
            // Everything else is joined to form the first column.
            let valueColumns = components.suffix(columnCount - 1)
            let firstColumn = components.dropLast(columnCount - 1).joined(separator: " ")
            
            var newRow = [firstColumn]
            newRow.append(contentsOf: Array(valueColumns))
            
            // Final check to ensure the reconstructed row matches the header count.
            guard newRow.count == columnCount else { return nil }
            
            parsedRows.append(newRow)
        }

        return (header, parsedRows)
    }
}