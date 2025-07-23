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
        // Return nil for empty strings
        if rawString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        
        do {
            // Use the SwiftCSV library to parse the string into a named CSV object.
            let csv = try CSV<Named>(string: rawString)
            let header = csv.header
            
            // Return nil if no header is found
            guard !header.isEmpty else {
                return nil
            }
            
            // Reconstruct each row as an array of strings, ensuring the order matches the header.
            let rows = csv.rows.map { row in
                header.map { field in row[field] ?? "" }
            }
            
            // Check for malformed CSV - if we have inconsistent column counts, return nil
            let expectedColumnCount = header.count
            for row in rows {
                if row.count != expectedColumnCount {
                    return nil
                }
            }
            
            return (header, rows)
        } catch {
            // If the SwiftCSV library throws an error (e.g., malformed CSV),
            // return nil to indicate that parsing failed.
            return nil
        }
    }
}