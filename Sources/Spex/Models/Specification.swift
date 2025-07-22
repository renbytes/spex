import Foundation
import TOMLKit

/// Represents the complete, structured specification for an analysis job.
///
/// This struct is the "single source of truth" that contains all user-defined
/// parameters for the code generation task. It is decoded from a `.toml` file
/// and then used to populate the prompt template.
struct Specification: Codable {
    let language: String
    let analysisType: String
    let description: String
    var datasets: [Dataset]
    let metrics: [Metric]

    // These keys are used for DECODING from the TOML file.
    enum CodingKeys: String, CodingKey {
        case language
        case analysisType = "analysis_type"
        case description
        case datasets = "dataset"
        case metrics = "metric"
    }

    // A separate enum with PLURAL keys for ENCODING to JSON for the templates.
    private enum EncodingCodingKeys: String, CodingKey {
        case language
        case analysisType = "analysis_type"
        case description
        case datasets // Plural
        case metrics  // Plural
    }

    /// Manually encodes the Specification to ensure the keys are plural,
    /// which is what the templates and tests expect.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: EncodingCodingKeys.self)
        try container.encode(self.language, forKey: .language)
        try container.encode(self.analysisType, forKey: .analysisType)
        try container.encode(self.description, forKey: .description)
        try container.encode(self.datasets, forKey: .datasets)
        try container.encode(self.metrics, forKey: .metrics)
    }
}

/// Represents a single input dataset for the analysis.
struct Dataset: Codable {
    let name: String
    let description: String
    let sampleDataPath: String?
    let dbConnection: String?

    /// This field is populated after the initial decoding by fetching the data.
    var schemaOrSample: String = ""

    enum CodingKeys: String, CodingKey {
        case name, description
        case sampleDataPath = "sample_data_path"
        case dbConnection = "db_connection"
    }

    /// Decodes a `Dataset` instance, manually initializing `schemaOrSample`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.sampleDataPath = try container.decodeIfPresent(String.self, forKey: .sampleDataPath)
        self.dbConnection = try container.decodeIfPresent(String.self, forKey: .dbConnection)
        self.schemaOrSample = ""
    }

    /// Encodes a `Dataset` instance, skipping the runtime-only `schemaOrSample` property.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(sampleDataPath, forKey: .sampleDataPath)
        try container.encodeIfPresent(dbConnection, forKey: .dbConnection)
    }

    /// A convenience initializer for programmatic creation, especially useful in tests.
    init(name: String, description: String, sampleDataPath: String?, dbConnection: String?, schemaOrSample: String = "") {
        self.name = name
        self.description = description
        self.sampleDataPath = sampleDataPath
        self.dbConnection = dbConnection
        self.schemaOrSample = schemaOrSample
    }
}

/// Represents a single metric to be calculated in the analysis.
struct Metric: Codable {
    let name: String
    let logic: String
    let aggregation: Aggregation
    let aggregationField: String

    enum CodingKeys: String, CodingKey {
        case name, logic, aggregation
        case aggregationField = "aggregation_field"
    }
}

// MARK: - Factory and Validation Logic
extension Specification {

    /// Builds a `Specification` instance from command-line arguments.
    static func build(from args: GenerateCommand.Arguments) async throws -> Specification {
        let specURL = URL(fileURLWithPath: args.spec)

        let fileContent: String
        do {
            fileContent = try String(contentsOf: specURL, encoding: .utf8)
        } catch {
            throw AppError.fileReadError("Could not read spec file at '\(args.spec)': \(error.localizedDescription)")
        }

        var spec: Specification
        do {
            spec = try TOMLDecoder().decode(Specification.self, from: fileContent)
        } catch {
            throw AppError.parsingError("Failed to parse TOML from '\(args.spec)': \(error.localizedDescription)")
        }

        try validate(spec: spec)

        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, dataset) in spec.datasets.enumerated() {
                group.addTask {
                    let schema = try await fetchSchemaOrSample(for: dataset)
                    return (index, schema)
                }
            }

            for try await (index, schema) in group {
                spec.datasets[index].schemaOrSample = schema
            }
        }

        return spec
    }

    /// Validates the contents of the specification against business rules.
    private static func validate(spec: Specification) throws {
        let maxDescLen = 50
        if spec.description.count > maxDescLen {
            throw AppError.validationError("The 'description' field is too long. Please keep it under \(maxDescLen) characters (currently \(spec.description.count)).")
        }

        let maxTypeLen = 30
        if spec.analysisType.count > maxTypeLen {
            throw AppError.validationError("The 'analysis_type' field is too long. Please keep it under \(maxTypeLen) characters (currently \(spec.analysisType.count)).")
        }
    }

    /// Fetches schema or sample data for a given dataset.
    private static func fetchSchemaOrSample(for dataset: Dataset) async throws -> String {
        guard let path = dataset.sampleDataPath else {
            throw AppError.inputError("Dataset '\(dataset.name)' must have a 'sample_data_path' defined.")
        }
        return try readSampleData(from: path)
    }

    /// Reads the first few lines of a sample data file.
    private static func readSampleData(from path: String) throws -> String {
        let maxLines = 6
        let fileURL = URL(fileURLWithPath: path)

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw AppError.fileReadError("Failed to open sample data file '\(path)': \(error.localizedDescription)")
        }

        let lines = content.split(separator: "\n", maxSplits: maxLines, omittingEmptySubsequences: false)
        let sample = lines.joined(separator: "\n")

        if sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.inputError("Sample data file '\(path)' is empty.")
        }

        return sample
    }

    /// Returns the content for a default `spec.toml` file.
    static func getDefaultTomlContent() -> String {
        return """
        # spec.toml
        language = "pyspark"
        analysis_type = "Ad-Attributed Subscriptions"
        description = "Analyzes user events to attribute signups to ad clicks."
        [[dataset]]
        name = "engagements"
        description = "Raw user engagement events, including ad impressions and clicks."
        sample_data_path = "examples/consumer_tech/engagements.csv"
        [[dataset]]
        name = "signups"
        description = "Subscription signup events, including organic and potentially attributed signups."
        sample_data_path = "examples/consumer_tech/signups.csv"
        [[dataset]]
        name = "products"
        description = "Product metadata mapping product_id to plan names."
        sample_data_path = "examples/consumer_tech/products.csv"
        [[metric]]
        name = "total_ad_impressions"
        logic = "A simple count of events from the engagements table where event_name is 'ad_impression'."
        aggregation = "Count"
        aggregation_field = "event_name"
        [[metric]]
        name = "total_ad_clicks"
        logic = "A simple count of events from the engagements table where event_name is 'ad_click'."
        aggregation = "Count"
        aggregation_field = "event_name"
        [[metric]]
        name = "total_signups"
        logic = "A simple count of all rows in the signups table."
        aggregation = "Count"
        aggregation_field = "user_id"
        [[metric]]
        name = "attributed_signups"
        logic = "The core attribution logic. For each signup, find the most recent 'ad_click' event from the same user that occurred *before* the signup_timestamp. If such a click exists, the signup is attributed. Count the distinct attributed user_ids."
        aggregation = "CountDistinct"
        aggregation_field = "user_id"
        [[metric]]
        name = "click_to_signup_rate"
        logic = "The percentage of total ad clicks that resulted in an attributed signup. Calculated as (attributed_signups / total_ad_clicks) * 100."
        aggregation = "Avg"
        aggregation_field = "click_to_signup_rate"
        [[metric]]
        name = "attributed_signups_by_plan"
        logic = "Join the attributed signups with the products table on product_id. Then, count the number of attributed signups for each human-readable product plan (e.g., 'Annual Streaming', 'Monthly Streaming')."
        aggregation = "Count"
        aggregation_field = "plan_name"
        """
    }
}
