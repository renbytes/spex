import Foundation
import Rainbow

/// The main orchestrator for the application logic. This component ties together all the
/// services required to execute a command, such as loading settings, building specifications,
/// generating code, and writing files.
final actor AppOrchestrator {

    /// Executes the `generate` command workflow.
    ///
    /// This is the primary logic path for the application. It orchestrates the process by:
    /// 1. Initializing settings and the LLM client.
    /// 2. Using `SpecLoader` to load and parse the `spec.toml` file.
    /// 3. Using `SpecValidator` to validate the loaded specification.
    /// 4. Enriching the specification with sample data from disk.
    /// 5. Passing the fully prepared `Specification` to the `CodeGenerator`.
    /// 6. Writing the generated project to disk with `CodeWriter`.
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

        // --- 4. Load, Validate, and Enrich Specification ---
        let specLoader = SpecLoader()
        var spec = try specLoader.load(from: args.spec)
        print("Specification loaded and parsed.".yellow)

        let specValidator = SpecValidator()
        try specValidator.validate(spec)
        print("Specification validated.".yellow)

        spec = try await enrich(spec: spec)
        print("Specification enriched with sample data.".yellow)

        // --- 5. Generate Code ---
        let generator = try CodeGenerator(llmClient: llmClient)
        let generatedCode = try await generator.generate(spec: spec, model: model)
        print("Code generation complete.".yellow)

        // --- 6. Write Files to Disk ---
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
                    userInfo: [NSLocalizedDescriptionKey: "A file named '\(specFilename)' already exists in this directory."]
                )
            )
        }

        // Get the default content and write the file.
        let content = self.getDefaultTomlContent()
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Successfully created '\(specFilename)'.".green)
            print("   Fill it out and run `spex generate --spec \(specFilename)`")
        } catch {
            throw AppError.fileWriteError(path: specFilename, source: error)
        }
    }

    // MARK: - Private Helpers

    /// Enriches a `Specification` by fetching and embedding sample data for each dataset.
    private func enrich(spec: Specification) async throws -> Specification {
        var mutableSpec = spec
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, dataset) in mutableSpec.datasets.enumerated() {
                group.addTask {
                    guard let path = dataset.sampleDataPath else {
                        throw AppError.inputError("Dataset '\(dataset.name)' must have a 'sample_data_path' defined.")
                    }
                    // Add 'await' here because we are calling an actor's method from a concurrent task.
                    let sample = try await self.readSampleData(from: path)
                    return (index, sample)
                }
            }

            for try await (index, schema) in group {
                mutableSpec.datasets[index].schemaOrSample = schema
            }
        }
        return mutableSpec
    }

    /// Reads the first few lines of a sample data file.
    private func readSampleData(from path: String) throws -> String {
        let maxLines = 6
        let fileURL = URL(fileURLWithPath: path)

        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw AppError.fileReadError("Failed to open sample data file '\(path)': \(error.localizedDescription)")
        }

        let lines = content.split(separator: "\n", maxSplits: maxLines, omittingEmptySubsequences: false)
        let sample = lines.joined(separator: "\n")

        if sample.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.inputError("Sample data file '\(path)' is empty.")
        }

        return sample
    }

    /// Returns the content for a default `spec.toml` file.
    private func getDefaultTomlContent() -> String {
        return """
        # spec.toml
        language = "pyspark"
        analysis_type = "Ad-Attributed Subscriptions"
        description = "Analyzes user events to attribute signups to ad clicks."
        [[dataset]]
        name = "engagements"
        description = "Raw user engagement events, including ad impressions and clicks."
        sample_data_path = "examples/consumer_tech/engagements.csv"
        [[dataset]]
        name = "signups"
        description = "Subscription signup events, including organic and potentially attributed signups."
        sample_data_path = "examples/consumer_tech/signups.csv"
        [[dataset]]
        name = "products"
        description = "Product metadata mapping product_id to plan names."
        sample_data_path = "examples/consumer_tech/products.csv"
        [[metric]]
        name = "total_ad_impressions"
        logic = "A simple count of events from the engagements table where event_name is 'ad_impression'."
        aggregation = "Count"
        aggregation_field = "event_name"
        [[metric]]
        name = "total_ad_clicks"
        logic = "A simple count of events from the engagements table where event_name is 'ad_click'."
        aggregation = "Count"
        aggregation_field = "event_name"
        [[metric]]
        name = "total_signups"
        logic = "A simple count of all rows in the signups table."
        aggregation = "Count"
        aggregation_field = "user_id"
        [[metric]]
        name = "attributed_signups"
        logic = "The core attribution logic. For each signup, find the most recent 'ad_click' event from the same user that occurred *before* the signup_timestamp. If such a click exists, the signup is attributed. Count the distinct attributed user_ids."
        aggregation = "CountDistinct"
        aggregation_field = "user_id"
        [[metric]]
        name = "click_to_signup_rate"
        logic = "The percentage of total ad clicks that resulted in an attributed signup. Calculated as (attributed_signups / total_ad_clicks) * 100."
        aggregation = "Avg"
        aggregation_field = "click_to_signup_rate"
        [[metric]]
        name = "attributed_signups_by_plan"
        logic = "Join the attributed signups with the products table on product_id. Then, count the number of attributed signups for each human-readable product plan (e.g., 'Annual Streaming', 'Monthly Streaming')."
        aggregation = "Count"
        aggregation_field = "plan_name"
        """
    }
}
