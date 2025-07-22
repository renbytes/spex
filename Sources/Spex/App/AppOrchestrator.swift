import Foundation
import Rainbow

/// The main orchestrator for the application logic. This component ties together all the
/// services required to execute a command, such as loading settings, building specifications,
/// generating code, and writing files.
final actor AppOrchestrator {

    /// Executes the `generate` command workflow.
    ///
    /// This is the primary logic path for the application. It performs the following steps:
    /// 1. Initializes application settings from environment variables and `.env` files.
    /// 2. Selects the appropriate LLM provider and model based on user input or defaults.
    /// 3. Initializes the corresponding LLM client.
    /// 4. Builds a `Specification` from the user-provided `.toml` file.
    /// 5. Initializes the `CodeGenerator` with the LLM client.
    /// 6. Calls the generator to produce the raw code output from the LLM.
    /// 7. Initializes the `CodeWriter` and writes the generated project to disk.
    ///
    /// - Parameter args: The parsed arguments from the `GenerateCommand`.
    /// - Throws: An `AppError` if any step in the process fails.
    func runGenerate(args: GenerateCommand.Arguments) async throws {
        // --- 1. Initialize Configuration ---
        let settings = Settings()
        print("Configuration loaded.".yellow)

        // --- 2. Determine LLM Provider and Model ---
        let provider = args.provider ?? .openai
        let model: String
        
        switch provider {
        case .openai:
            model = args.model ?? settings.openaiDefaultModel
        case .gemini:
            model = args.model ?? settings.geminiDefaultModel
        case .internalGw:
            model = args.model ?? settings.geminiDefaultModel
        }

        // --- 3. Initialize LLM Client ---
        let llmClient: any LlmClient
            switch provider {
                case .openai:
                    llmClient = try OpenAIClient(settings: settings)
                case .gemini:
                    llmClient = try GeminiClient(settings: settings)
                case .internalGw:
                    llmClient = InternalClient(settings: settings)
            }
        print("Using provider: \(provider.rawValue.capitalized), model: \(model)".yellow)

        // --- 4. Build Specification & Generate Code ---
        let spec = try await Specification.build(from: args)
        print("Specification built successfully.".yellow)

        let generator = try CodeGenerator(llmClient: llmClient)
        let generatedCode = try await generator.generate(spec: spec, model: model)
        print("Code generation complete.".yellow)

        // --- 5. Write Files to Disk ---
        let writer = try CodeWriter()
        try writer.writeFiles(rawOutput: generatedCode, spec: spec)
    }

    /// Executes the `init` command workflow.
    ///
    /// This function creates a default `spec.toml` file in the current directory
    /// to help users get started. It will fail if the file already exists to prevent
    /// accidentally overwriting user work.
    ///
    /// - Throws: An `AppError.fileWriteError` if the file already exists or cannot be written.
    func runInit() throws {
        let specFilename = "spec.toml"
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let fileURL = currentDirectoryURL.appendingPathComponent(specFilename)

        // Check if the file already exists.
        if fileManager.fileExists(atPath: fileURL.path) {
            throw AppError.fileWriteError(
                path: specFilename,
                source: NSError(
                    domain: "Spex",
                    code: 1,
                    // Dictionary with a description for the userInfo parameter
                    userInfo: [NSLocalizedDescriptionKey: "A file named '\(specFilename)' already exists in this directory."]
                )
            )
        }

        // Get the default content and write the file.
        let content = Specification.getDefaultTomlContent()
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Successfully created '\(specFilename)'.".green)
            print("   Fill it out and run `spex generate --spec \(specFilename)`")
        } catch {
            throw AppError.fileWriteError(path: specFilename, source: error)
        }
    }
}
