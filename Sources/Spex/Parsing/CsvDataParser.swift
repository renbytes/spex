import Foundation
import SwiftCSV

/// A parser for interpreting comma-separated value (CSV) strings.
///
/// This parser relies on the `SwiftCSV` library to handle standard CSV formatting,
/// including headers and properly quoted fields.
///
/// ### Example Input
/// The `rawString` parameter is expected to be a standard CSV format:
/// ```text
/// id,name,value,category
/// 1,alpha,100,"gadgets"
/// 2,beta,200,"widgets"
/// 3,gamma,150,"gadgets"
/// ```
struct CsvDataParser: DataParser {
    func parse(from rawString: String) -> ParsedSample? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }

        do {
            // Skip the manual pre-validation - let SwiftCSV handle it
            let csv = try CSV<Named>(string: trimmed)
            let header = csv.header

            guard !header.isEmpty else {
                return nil
            }

            // Convert the dictionary rows to arrays, preserving header order.
            let rows = csv.rows.map { namedRow in
                header.map { columnName in
                    namedRow[columnName] ?? ""
                }
            }

            return (header, rows)
        } catch {
            // If SwiftCSV fails, fall back to simple line-based parsing
            return parseAsSimpleCSV(trimmed)
        }
    }
    
    private func parseAsSimpleCSV(_ content: String) -> ParsedSample? {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard lines.count >= 2 else { return nil }
        
        let header = lines[0].components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let rows = lines.dropFirst().map { line in
            line.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        
        // Validate all rows have same column count as header
        for row in rows {
            if row.count != header.count {
                return nil
            }
        }
        
        return (header, rows)
    }
}
