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
    var outputDatasets: [Dataset]?

    // These keys are used for DECODING from the TOML file.
    enum CodingKeys: String, CodingKey {
        case language
        case analysisType = "analysis_type"
        case description
        case datasets = "dataset"
        case metrics = "metric"
        case outputDatasets = "output_dataset"
    }

    // A separate enum with PLURAL keys for ENCODING to JSON for the templates.
    // I noticed that tests were flaky if not pluralized, hence separate enum between decoding and encoding.
    private enum EncodingCodingKeys: String, CodingKey {
        case language
        case analysisType = "analysis_type"
        case description
        case datasets 
        case metrics
        case outputDatasets = "output_datasets"
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
        try container.encodeIfPresent(self.outputDatasets, forKey: .outputDatasets)
    }
}

/// Represents a single input or output dataset for the analysis.
struct Dataset: Codable {
    let name: String
    let description: String
    let sampleDataPath: String?
    let sampleDataBlock: String?
    let dbConnection: String?

    /// This field is populated after the initial decoding by fetching the data.
    var schemaOrSample: String = ""

    enum CodingKeys: String, CodingKey {
        case name, description
        case sampleDataPath = "sample_data_path"
        case sampleDataBlock = "sample_data_block"
        case dbConnection = "db_connection"
    }

    /// Decodes a `Dataset` instance, manually initializing `schemaOrSample`.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decode(String.self, forKey: .description)
        self.sampleDataPath = try container.decodeIfPresent(String.self, forKey: .sampleDataPath)
        self.sampleDataBlock = try container.decodeIfPresent(String.self, forKey: .sampleDataBlock)
        self.dbConnection = try container.decodeIfPresent(String.self, forKey: .dbConnection)
        self.schemaOrSample = ""
    }

    /// Encodes a `Dataset` instance, skipping the runtime-only `schemaOrSample` property.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(sampleDataPath, forKey: .sampleDataPath)
        try container.encodeIfPresent(sampleDataBlock, forKey: .sampleDataBlock)
        try container.encodeIfPresent(dbConnection, forKey: .dbConnection)
    }

    /// A convenience initializer for programmatic creation, especially useful in tests.
    init(name: String, description: String, sampleDataPath: String? = nil, sampleDataBlock: String? = nil, dbConnection: String? = nil, schemaOrSample: String = "") {
        self.name = name
        self.description = description
        self.sampleDataPath = sampleDataPath
        self.sampleDataBlock = sampleDataBlock
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
