import XCTest
@testable import Spex

/// A targeted test to debug configuration and environment variable loading.
final class ConfigurationTests: XCTestCase {

    /// This test bypasses the .env file completely to verify that the
    /// Settings struct can load keys directly from the environment.
    func testSettingsLoadsDirectlyFromEnvironmentVariables() throws {
        // ARRANGE
        // Define mock keys and set them as environment variables for this test.
        let mockOpenAIKey = "test_openai_key_123"
        let mockGeminiKey = "test_gemini_key_456"
        
        setenv("OPENAI_API_KEY", mockOpenAIKey, 1)
        setenv("GEMINI_API_KEY", mockGeminiKey, 1)

        // Ensure the environment variables are cleaned up after the test runs.
        defer {
            unsetenv("OPENAI_API_KEY")
            unsetenv("GEMINI_API_KEY")
        }

        // ACT
        // Initialize the Settings object. It will read from the environment
        // variables we just set.
        let settings = Settings()

        // ASSERT
        // Check that the properties were populated correctly.
        XCTAssertNotNil(settings.openaiApiKey, "The OpenAI API key should not be nil.")
        XCTAssertEqual(settings.openaiApiKey, mockOpenAIKey, "The OpenAI key does not match the expected mock value.")
        
        XCTAssertNotNil(settings.geminiApiKey, "The Gemini API key should not be nil.")
        XCTAssertEqual(settings.geminiApiKey, mockGeminiKey, "The Gemini key does not match the expected mock value.")
    }
}
