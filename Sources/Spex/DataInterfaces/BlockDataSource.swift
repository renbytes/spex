import Foundation

/// A data source that reads data directly from an inline string block in the spec file.
/// It assumes the block is already formatted and does not require parsing.
struct BlockDataSource: DataSource {
  func fetchSchemaAndSample(for dataset: Dataset) async throws -> String {
    guard let block = dataset.sampleDataBlock else {
      throw AppError.inputError("Dataset '\(dataset.name)' is missing a 'sample_data_block'.")
    }
    // The block is returned as-is, assuming it's pre-formatted for the LLM.
    return block
  }
}
