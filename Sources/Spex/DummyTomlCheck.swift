import Foundation
import TOMLKit

struct DummyTomlCheck {
    static func run() {
        let path = "/Users/bordumb/workspace/repositories/spex/examples/consumer_tech/spec.toml"
        let url = URL(fileURLWithPath: path)

        do {
            var fileContent = try String(contentsOf: url, encoding: .utf8)
            fileContent += "\nsource_name = \"debugging_test\"\n"

            let spec = try TOMLDecoder().decode(DummySpec.self, from: fileContent)
            print("✅ Successfully decoded TOML!")
            print("🔹 Spec language: \(spec.language)")
            print("🔹 First dataset: \(spec.dataset.first?.name ?? "none")")
        } catch {
            print("❌ Failed with error: \(error)")
        }
    }
}

// Dummy models copied here
struct DummyDataset: Decodable {
    let name: String
    let description: String
    let sampleDataPath: String?

    enum CodingKeys: String, CodingKey {
        case name, description
        case sampleDataPath = "sample_data_path"
    }
}

struct DummyMetric: Decodable {
    let name: String
    let logic: String
    let aggregation: String
    let aggregationField: String

    enum CodingKeys: String, CodingKey {
        case name, logic, aggregation
        case aggregationField = "aggregation_field"
    }
}

struct DummySpec: Decodable {
    let language: String
    let analysisType: String
    let description: String
    let dataset: [DummyDataset]
    let metric: [DummyMetric]

    enum CodingKeys: String, CodingKey {
        case language
        case analysisType = "analysis_type"
        case description
        case dataset
        case metric
    }
}