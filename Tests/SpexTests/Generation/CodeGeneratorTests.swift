import XCTest

@testable import Spex

/// A mock `LlmClient` implemented as an actor to handle state in a concurrent environment.
final actor MockLlmClient: LlmClient {
    private(set) var promptReceived: String?
    var responseToReturn: Result<String, AppError> = .success("Mock LLM Response")

    func generateCode(prompt: String, model: String) async throws -> String {
        self.promptReceived = prompt
        return try responseToReturn.get()
    }
}

/// Unit tests for the `CodeGenerator` component.
final class GeneratorTests: XCTestCase {

    /// Tests that the `CodeGenerator` selects and renders the correct prompt template
    /// based on the language specified in the `Specification`.
    func testGenerateUsesCorrectTemplate() async throws {
        // ARRANGE
        // The Specification is now a pure data model, making it easy to create in memory.
        let spec = Specification(
            language: "pyspark",
            analysisType: "Test Analysis",
            description: "A test description.",
            datasets: [],
            metrics: [
                Metric(
                    name: "test_metric",
                    logic: "A test metric.",
                    aggregation: .count,
                    aggregationField: "id"
                )
            ]
        )

        let mockClient = MockLlmClient()
        let generator = try CodeGenerator(llmClient: mockClient)

        // ACT
        _ = try await generator.generate(spec: spec, model: "test-model")

        // ASSERT
        let promptValue = await mockClient.promptReceived
        let receivedPrompt = try XCTUnwrap(promptValue, "The prompt received by the mock LLM client was nil.")

        let expectedPysparkText = "You are an expert-level big data engineering and PySpark code generator."

        // Check for the correct PySpark text and fail with a descriptive message if it's missing.
        guard receivedPrompt.contains(expectedPysparkText) else {
            XCTFail(
                """
                The generated prompt did not contain the expected PySpark-specific text.
                ---
                EXPECTED TO FIND:
                "\(expectedPysparkText)"
                ---
                RECEIVED PROMPT:
                "\(receivedPrompt)"
                """)
            return
        }

        XCTAssertTrue(
            receivedPrompt.contains("Target Language: pyspark"), "The prompt should contain the target language.")
        XCTAssertFalse(
            receivedPrompt.contains("You are an expert-level data engineering and data science code generator."),
            "The prompt should not contain text from the generic python template.")
    }
}
