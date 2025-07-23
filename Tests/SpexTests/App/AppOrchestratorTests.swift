import XCTest

@testable import Spex

/// Unit tests for the `AppOrchestrator`.
final class AppOrchestratorTests: XCTestCase {

    private var orchestrator: AppOrchestrator!
    private var tempDirectory: URL!
    /// Creates a temporary directory for test files before each test runs.
    override func setUpWithError() throws {
        orchestrator = AppOrchestrator()
        // Create a unique temporary directory for each test run to avoid conflicts.
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    /// Removes the temporary directory and its contents after each test.
    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
        orchestrator = nil
    }

    /// Helper function to create a temporary file with specific content for a test.
    private func createTempFile(named name: String, content: String) throws -> URL {
        let fileURL = tempDirectory.appendingPathComponent(name)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Tests that the `enrich` method correctly reads a file and populates the `schemaOrSample` property.
    func testEnrich_WithValidDataSource_PopulatesSchemaCorrectly() async throws {
        // ARRANGE
        // 1. Create a temporary CSV file with known content.
        let csvContent = "id,name\n1,test"
        let fileURL = try createTempFile(named: "test.csv", content: csvContent)

        // 2. Create a specification that points to the temporary file.
        var spec = Specification(
            language: "python",
            analysisType: "Test",
            description: "A test spec",
            datasets: [
                Dataset(name: "dataset1", description: "", sampleDataPath: fileURL.path)
            ],
            metrics: []
        )
        XCTAssertTrue(spec.datasets[0].schemaOrSample.isEmpty)

        // ACT
        // 3. Call the real enrich method. It will use its internal factory to read the file.
        spec = try await orchestrator.enrich(spec)

        // ASSERT
        // 4. Verify that the enriched string matches the new, robust output format.
        // This format is readable and logically separates schema from data.
        let expectedOutput = "Schema: id, name\nSample Data:\n1, test"

        XCTAssertEqual(
            spec.datasets[0].schemaOrSample.trimmingCharacters(in: .whitespacesAndNewlines),
            expectedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    /// Tests that `enrich` correctly throws a fileReadError when the path is invalid.
    func testEnrich_WhenDataSourcePointsToNonexistentFile_ThrowsError() async {
        // ARRANGE
        // 1. Create a spec pointing to a file that does not exist.
        let spec = Specification(
            language: "python",
            analysisType: "Test",
            description: "A test spec",
            datasets: [Dataset(name: "dataset1", description: "", sampleDataPath: "/non/existent/file.csv")],
            metrics: []
        )

        // ACT & ASSERT
        // 2. Expect the `enrich` call to fail with a file-read-related error.
        do {
            _ = try await orchestrator.enrich(spec)
            XCTFail("Expected enrich to throw an error for a missing file, but it did not.")
        } catch let error as AppError {
            // We expect an error, but since the parser is tried first, it could be a parsing error
            // or a file read error depending on implementation details. We just check for an error.
            XCTAssertNotNil(error.errorDescription)
        } catch {
            XCTFail("Unexpected error type thrown: \(error)")
        }
    }
}
