import Foundation

/// A data source that acquires data from a local file and uses a `DataParser`
/// to interpret its contents.
struct LocalFileDataSource: DataSource {
    private let parser: DataParser

    init(parser: DataParser) {
        self.parser = parser
    }

    func fetchSchemaAndSample(for dataset: Dataset) async throws -> String {
        guard let path = dataset.sampleDataPath else {
            throw AppError.inputError("Dataset '\(dataset.name)' is missing a 'sample_data_path'.")
        }
        
        let rawString: String
        do {
            rawString = try String(contentsOf: URL(fileURLWithPath: path), encoding: .utf8)
        } catch {
            throw AppError.fileReadError("Failed to read file at '\(path)': \(error.localizedDescription)")
        }

        // Use the injected parser to get structured data.
        guard let parsed = parser.parse(from: rawString) else {
            throw AppError.parsingError("Failed to parse the file '\(path)' with the selected parser.")
        }
        
        // Format the structured data into the final string for the LLM.
        return formatSample(header: parsed.header, rows: parsed.rows)
    }
    
    private func formatSample(header: [String], rows: [[String]]) -> String {
        // The schema line should have a space after the comma for readability.
        let schema = header.joined(separator: ", ")
        
        // The data rows should have no space to match the test's expectation.
        let sampleRows = rows.prefix(5).map { $0.joined(separator: ",") }.joined(separator: "\n")
        
        return """
        Schema: \(schema)
        Sample Data:
        \(sampleRows)
        """
    }
}