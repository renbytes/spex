import XCTest
@testable import Spex

/// Unit tests for the `SpecLoader` service.
///
/// These tests validate the file reading and parsing capabilities of `SpecLoader`,
/// ensuring it correctly decodes valid TOML files and handles errors for
/// invalid paths or malformed content.
final class SpecLoaderTests: XCTestCase {

    var tempDirectory: URL!

    /// Creates a temporary directory for test files before each test.
    override func setUpWithError() throws {
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    /// Removes the temporary directory after each test.
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    /// Writes content to a temporary file and returns its URL.
    private func createTempFile(named name: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    // MARK: - Tests

    /// Tests that the loader successfully parses a valid `spec.toml` file.
    func testLoad_WithValidFile_Succeeds() throws {
        // ARRANGE
        let validToml = """
        language = "python"
        analysis_type = "Test"
        description = "A valid test spec"
        [[dataset]]
        name = "my_data"
        description = "Some data"
        sample_data_path = "path/to/data.csv"
        [[metric]]
        name = "my_metric"
        logic = "Some logic"
        aggregation = "Count"
        aggregation_field = "id"
        """
        let fileURL = try createTempFile(named: "spec.toml", content: validToml)
        let loader = SpecLoader()

        // ACT
        let spec = try loader.load(from: fileURL.path)

        // ASSERT
        XCTAssertEqual(spec.language, "python")
        XCTAssertEqual(spec.analysisType, "Test")
        XCTAssertEqual(spec.datasets.count, 1)
        XCTAssertEqual(spec.datasets.first?.name, "my_data")
        XCTAssertEqual(spec.metrics.count, 1)
        XCTAssertEqual(spec.metrics.first?.name, "my_metric")
    }

    /// Tests that the loader throws a `fileReadError` when the file does not exist.
    func testLoad_WithNonExistentFile_ThrowsFileReadError() {
        // ARRANGE
        let loader = SpecLoader()
        let nonExistentPath = "/non/existent/path/spec.toml"

        // ACT & ASSERT
        XCTAssertThrowsError(try loader.load(from: nonExistentPath)) { error in
            guard case .fileReadError = error as? AppError else {
                return XCTFail("Expected AppError.fileReadError but got \(error)")
            }
            // Success
        }
    }

    /// Tests that the loader throws a `parsingError` for malformed TOML content.
    func testLoad_WithMalformedToml_ThrowsParsingError() throws {
        // ARRANGE
        let malformedToml = "this is not valid toml"
        let fileURL = try createTempFile(named: "bad_spec.toml", content: malformedToml)
        let loader = SpecLoader()

        // ACT & ASSERT
        XCTAssertThrowsError(try loader.load(from: fileURL.path)) { error in
            guard case .parsingError = error as? AppError else {
                return XCTFail("Expected AppError.parsingError but got \(error)")
            }
            // Success
        }
    }
}
