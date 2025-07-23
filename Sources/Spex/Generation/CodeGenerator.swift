import Foundation

/// The engine for the code generation process.
///
/// This component orchestrates the core logic of the application by taking a user-defined
/// `Specification`, loading the appropriate prompt template, rendering it with the
/// spec's details, and then passing the final prompt to an `LlmClient` to
/// generate the desired code.
struct CodeGenerator {

    // MARK: Properties

    private let llmClient: any LlmClient
    private let templatesURL: URL

    // MARK: Initialization

    /// Creates a new `CodeGenerator`.
    ///
    /// - Parameter llmClient: An instance of a type conforming to `LlmClient`.
    /// - Throws: `AppError.configError` if the templates directory cannot be located.
    init(llmClient: any LlmClient) throws {
        self.llmClient = llmClient
        self.templatesURL = try Self.findProjectRoot().appendingPathComponent("configs")
    }

    /// A robust helper to find the project root directory by searching upwards for `Package.swift`.
    private static func findProjectRoot(from path: String = #file) throws -> URL {
        let currentFileURL = URL(fileURLWithPath: path)
        var currentURL = currentFileURL
        while currentURL.pathComponents.count > 1 {
            let potentialRoot = currentURL.deletingLastPathComponent()
            let packageSwiftPath = potentialRoot.appendingPathComponent("Package.swift").path
            if FileManager.default.fileExists(atPath: packageSwiftPath) {
                return potentialRoot
            }
            currentURL = potentialRoot
        }
        throw AppError.configError("Could not locate project root from path \(path).")
    }

    // MARK: Public Methods

    /// Generates code by rendering a prompt and calling the LLM client.
    ///
    /// This method executes the code generation workflow:
    /// 1. Constructs the path to the correct template file based on the language.
    /// 2. Loads the template content from disk.
    /// 3. Converts the `Specification` object into a dictionary for the template.
    /// 4. Renders the template using `TemplateRenderer`, producing the final prompt string.
    /// 5. Calls the `llmClient` with the generated prompt and the specified model.
    ///
    /// - Parameters:
    ///   - spec: The fully-populated `Specification` containing user requirements.
    ///   - model: The name of the model to use for generation.
    /// - Returns: The raw string response from the LLM.
    /// - Throws: An `AppError` if any step fails.
    func generate(spec: Specification, model: String) async throws -> String {
        let templatePath = templatesURL.appendingPathComponent(
            "\(spec.language.lowercased())/prompt_templates/default.tera")

        let templateContent: String
        do {
            templateContent = try String(contentsOf: templatePath, encoding: .utf8)
        } catch {
            throw AppError.templateError(
                "Failed to load template from '\(templatePath.path)': \(error.localizedDescription)")
        }

        // The context is the dictionary that holds all the data for the template.
        let context: [String: Any]
        do {
            context = try TemplateRenderer.specificationToContext(spec)
        } catch {
            throw AppError.templateError(
                "Failed to prepare spec for template context: \(error.localizedDescription)")
        }

        // Render the final prompt string using the template and its context.
        let prompt = try TemplateRenderer.render(template: templateContent, context: context)

        // Send the complete prompt to the LLM for code generation.
        return try await llmClient.generateCode(prompt: prompt, model: model)
    }
}
