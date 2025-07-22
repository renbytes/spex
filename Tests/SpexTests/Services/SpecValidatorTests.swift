import XCTest
@testable import Spex

/// Unit tests for the `SpecValidator` service.
///
/// These tests verify that the validation logic correctly identifies valid
/// specifications and rejects those that violate the defined business rules.
/// Because `SpecValidator` operates on in-memory objects, these tests
/// require no file I/O and can run very quickly.
final class SpecValidatorTests: XCTestCase {

    private var validator: SpecValidator!

    override func setUp() {
        super.setUp()
        validator = SpecValidator()
    }

    /// Creates a mock `Specification` for testing purposes.
    private func createMockSpec(
        language: String = "python",
        description: String = "A valid description",
        analysisType: String = "A valid type"
    ) -> Specification {
        return Specification(
            language: language,
            analysisType: analysisType,
            description: description,
            datasets: [],
            metrics: []
        )
    }

    // MARK: - Tests

    /// Tests that a valid specification passes validation without throwing an error.
    func testValidate_WithValidSpec_Succeeds() throws {
        // ARRANGE
        let spec = createMockSpec()

        // ACT & ASSERT
        XCTAssertNoThrow(try validator.validate(spec), "A valid spec should not throw an error.")
    }

    /// Tests that the validator throws an error if the description is too long.
    func testValidate_WithLongDescription_ThrowsValidationError() {
        // ARRANGE
        let longDescription = String(repeating: "a", count: 51)
        let spec = createMockSpec(description: longDescription)

        // ACT & ASSERT
        XCTAssertThrowsError(try validator.validate(spec)) { error in
            guard case .validationError(let message) = error as? AppError else {
                return XCTFail("Expected AppError.validationError")
            }
            XCTAssertTrue(message.contains("description' field is too long"))
        }
    }

    /// Tests that the validator throws an error if the analysis type is too long.
    func testValidate_WithLongAnalysisType_ThrowsValidationError() {
        // ARRANGE
        let longAnalysisType = String(repeating: "b", count: 31)
        let spec = createMockSpec(analysisType: longAnalysisType)

        // ACT & ASSERT
        XCTAssertThrowsError(try validator.validate(spec)) { error in
            guard case .validationError(let message) = error as? AppError else {
                return XCTFail("Expected AppError.validationError")
            }
            XCTAssertTrue(message.contains("analysis_type' field is too long"))
        }
    }

    /// Tests that a spec with a supported language (case-insensitive) passes validation.
    func testValidate_WithValidLanguage_Succeeds() throws {
        // ARRANGE
        let spec = createMockSpec(language: "PySpark") // Test case-insensitivity

        // ACT & ASSERT
        XCTAssertNoThrow(try validator.validate(spec))
    }

    /// Tests that the validator throws an error for an unsupported language.
    func testValidate_WithInvalidLanguage_ThrowsValidationError() {
        // ARRANGE
        let spec = createMockSpec(language: "rust")

        // ACT & ASSERT
        XCTAssertThrowsError(try validator.validate(spec)) { error in
            guard case .validationError(let message) = error as? AppError else {
                return XCTFail("Expected AppError.validationError")
            }
            XCTAssertTrue(message.contains("is not a supported language"))
            XCTAssertTrue(message.contains("python, pyspark, sql"))
        }
    }
}
