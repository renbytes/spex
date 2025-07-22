import Foundation

/// A service responsible for validating the business logic of a `Specification`.
///
/// This component isolates the validation rules from the core data model,
/// making the rules easier to test and maintain. It ensures that a given
// `Specification` object adheres to predefined constraints before it's used
/// in the code generation process.
struct SpecValidator {

    /// Validates a `Specification` object against a set of business rules.
    ///
    /// - Parameter spec: The `Specification` instance to validate.
    /// - Throws: An `AppError.validationError` if any rule is violated.
    func validate(_ spec: Specification) throws {
        // Rule 1: Check description length.
        let maxDescLen = 50
        if spec.description.count > maxDescLen {
            throw AppError.validationError(
                "The 'description' field is too long. Please keep it under \(maxDescLen) characters (currently \(spec.description.count))."
            )
        }

        // Rule 2: Check analysis type length.
        let maxTypeLen = 30
        if spec.analysisType.count > maxTypeLen {
            throw AppError.validationError(
                "The 'analysis_type' field is too long. Please keep it under \(maxTypeLen) characters (currently \(spec.analysisType.count))."
            )
        }

        // TODO: Add more validation rules as needed.
    }
}
