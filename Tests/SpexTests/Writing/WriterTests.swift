import XCTest

@testable import Spex

final class WriterTests: XCTestCase {

    var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: tempDirectory)
    }

    /// Tests that `writeFiles` correctly creates directories and writes content from a valid LLM output.
    func testWriteFilesCreatesCorrectDirectoryAndContent() throws {
        // ARRANGE
        let writer = try CodeWriter(baseDirectory: tempDirectory)

        let spec = Specification(
            language: "python",
            analysisType: "Simple Test",
            description: "A test of the writer.",
            datasets: [],
            metrics: []
        )

        let mockLlmOutput = """
            ### FILE: job.py
            ```python
            # This is the job file.
            print("hello from job")
            ```
            ### FILE: tests/test_job.py
            ```python
            # This is the test file.
            assert True
            ```
            """

        // ACT
        try writer.writeFiles(rawOutput: mockLlmOutput, spec: spec)

        // ASSERT
        let generatedDirs = try FileManager.default.contentsOfDirectory(
            at: tempDirectory.appendingPathComponent("generated_jobs/python/simple-test"),
            includingPropertiesForKeys: nil)
        XCTAssertEqual(generatedDirs.count, 1, "Should have created one timestamped directory.")

        let finalDir = try XCTUnwrap(generatedDirs.first)

        let jobFileURL = finalDir.appendingPathComponent("job.py")
        let testFileURL = finalDir.appendingPathComponent("tests/test_job.py")
        XCTAssertTrue(FileManager.default.fileExists(atPath: jobFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))

        let jobContent = try String(contentsOf: jobFileURL)
        let testContent = try String(contentsOf: testFileURL)
        XCTAssertEqual(
            jobContent.trimmingCharacters(in: .whitespacesAndNewlines),
            "# This is the job file.\nprint(\"hello from job\")")
        XCTAssertEqual(
            testContent.trimmingCharacters(in: .whitespacesAndNewlines), "# This is the test file.\nassert True")

        let readmeURL = finalDir.appendingPathComponent("README.md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: readmeURL.path))
    }
}
