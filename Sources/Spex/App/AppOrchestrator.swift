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
    /// 4. Using a `DataSource` to enrich the specification with sample data for both inputs and outputs.
    /// 5. Passing the fully prepared `Specification` to the `CodeGenerator`.
    /// 6. Writing the generated project to disk with `CodeWriter`.
    ///
    /// - Parameter args: The parsed arguments from the `GenerateCommand`.
    /// - Throws: An `AppError` if any step in the process fails.
    func runGenerate(args: GenerateCommand.Arguments) async throws {
        // --- 1. Initialize Configuration ---
        let settings = Settings()
        Logger.log("Configuration loaded.", type: .info)

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
        Logger.log("Using provider: \(provider.rawValue.capitalized), model: \(model)", type: .info)

        // --- 4. Load and Validate Specification ---
        let specLoader = SpecLoader()
        var spec = try specLoader.load(from: args.spec)
        Logger.log("Specification loaded and parsed.", type: .info)

        let specValidator = SpecValidator()
        try specValidator.validate(spec)
        Logger.log("Specification validated.", type: .info)

        // Add a warning if the optional output dataset is not provided.
        if spec.outputDatasets == nil || spec.outputDatasets!.isEmpty {
            Logger.log("No output dataset provided. Providing a sample output can improve generation quality.", type: .warning)
        }

        // --- 5. Enrich Specification with Sample Data ---
        spec = try await self.enrich(spec)
        Logger.log("Specification enriched with sample data.", type: .info)

        // --- 6. Generate Code ---
        let generator = try CodeGenerator(llmClient: llmClient)
        let generatedCode = try await generator.generate(spec: spec, model: model)
        Logger.log("Code generation complete.", type: .info)

        // --- 7. Write Files to Disk ---
        let writer = try CodeWriter()
        try writer.writeFiles(rawOutput: generatedCode, spec: spec)
    }

    /// Executes the `init` command workflow.
    func runInit() throws {
        let specFilename = "spec.toml"
        let fileManager = FileManager.default
        let currentDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        let fileURL = currentDirectoryURL.appendingPathComponent(specFilename)

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

        let content = self.getDefaultTomlContent()
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.log("Successfully created '\(specFilename)'", type: .success)
            print("   Fill it out and run `spex generate --spec \(specFilename)`")
        } catch {
            throw AppError.fileWriteError(path: specFilename, source: error)
        }
    }

    // MARK: - Internal Helpers for Testing

    /// Enriches a `Specification` by fetching and embedding sample data for both
    /// input and output datasets.
    internal func enrich(_ spec: Specification) async throws -> Specification {
        var mutableSpec = spec

        // Enrich input datasets
        var enrichedInputDatasets = mutableSpec.datasets
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, dataset) in enrichedInputDatasets.enumerated() {
                group.addTask {
                    guard let dataSource = DataSourceFactory.makeDataSource(for: dataset) else {
                        throw AppError.inputError("Input dataset '\(dataset.name)' is missing a 'sample_data_path' or 'sample_data_block'.")
                    }
                    let schemaAndSample = try await dataSource.fetchSchemaAndSample(for: dataset)
                    return (index, schemaAndSample)
                }
            }
            for try await (index, schema) in group {
                enrichedInputDatasets[index].schemaOrSample = schema
            }
        }
        mutableSpec.datasets = enrichedInputDatasets

        // Enrich output datasets if they exist
        if var outputDatasets = mutableSpec.outputDatasets {
            try await withThrowingTaskGroup(of: (Int, String).self) { group in
                for (index, dataset) in outputDatasets.enumerated() {
                    group.addTask {
                        guard let dataSource = DataSourceFactory.makeDataSource(for: dataset) else {
                            throw AppError.inputError("Output dataset '\(dataset.name)' is missing a 'sample_data_path' or 'sample_data_block'.")
                        }
                        let schemaAndSample = try await dataSource.fetchSchemaAndSample(for: dataset)
                        return (index, schemaAndSample)
                    }
                }
                for try await (index, schema) in group {
                    outputDatasets[index].schemaOrSample = schema
                }
            }
            mutableSpec.outputDatasets = outputDatasets
        }

        return mutableSpec
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
        
        [[output_dataset]]
        name = "attributed_signups_summary"
        description = "A summary table of signups attributed to ad clicks."
        sample_data_block = \"\"\"
        +---------+------------------+----------------------+
        | user_id | signup_plan      | timestamp            |
        +---------+------------------+----------------------+
        | 1       | monthly_premium  | 2025-07-23T10:02:00Z |
        | 3       | annual_basic     | 2025-07-23T11:30:00Z |
        +---------+------------------+----------------------+
        \"\"\"

        [[metric]]
        name = "total_ad_impressions"
        logic = "A simple count of events from the engagements table where event_name is 'ad_impression'."
        aggregation = "Count"
        aggregation_field = "event_name"

        [[metric]]
        name = "attributed_signups"
        logic = "The core attribution logic. For each signup, find the most recent 'ad_click' event from the same user that occurred *before* the signup_timestamp. If such a click exists, the signup is attributed."
        aggregation = "CountDistinct"
        aggregation_field = "user_id"
        """
    }
}
