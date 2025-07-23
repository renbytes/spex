import Foundation
import Rainbow
import Noora

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

        // --- 2. Determine LLM Provider and Model (with interactive prompt) ---
        var provider: LlmProvider
        if let specifiedProvider = args.provider {
            provider = specifiedProvider
        } else {
            let choices = LlmProvider.allCases.map { $0.rawValue.capitalized }
            // Use Noora() instance for prompts
            let noora = Noora()
            let chosenProviderName: String = noora.singleChoicePrompt(
                title: "LLM Provider Selection",
                question: "Which LLM provider would you like to use?",
                options: choices
            )
            provider = LlmProvider(rawValue: chosenProviderName.lowercased()) ?? .openai
            print() // Better spacing after the prompt
        }

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

        // --- 4. Load and Validate Specification ---
        let noora = Noora()
        var spec: Specification = try await noora.progressStep(message: "Loading and validating specification") { _ in
            let specLoader = SpecLoader()
            let loadedSpec = try specLoader.load(from: args.spec)

            let specValidator = SpecValidator()
            try specValidator.validate(loadedSpec)
            
            if loadedSpec.outputDatasets == nil || loadedSpec.outputDatasets!.isEmpty {
                Logger.log("No output dataset provided. Providing a sample output can improve generation quality.", type: .warning)
            }
            return loadedSpec
        }

        // --- 5. Enrich Specification with Sample Data ---
        spec = try await noora.progressStep(message: "Enriching specification with sample data") { _ in
            try await self.enrich(spec)
        }

        // --- 6. Generate Code ---
        let generatedCode = try await noora.progressStep(message: "Generating project code via \(provider.rawValue.capitalized) (\(model))") { _ in
            let generator = try CodeGenerator(llmClient: llmClient)
            return try await generator.generate(spec: spec, model: model)
        }

        // --- 7. Write Files to Disk ---
        let outputDir = try await noora.progressStep(message: "Writing project files to disk") { _ in
            let writer = try CodeWriter()
            return try writer.writeFiles(rawOutput: generatedCode, spec: spec)
        }
        
        print("\n🎉".bold, "Successfully generated project!".bold)
        print("   Location: \(outputDir.path.cyan)")
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

// MARK: - Interactive Mode Extension

extension AppOrchestrator {
    
    /// Runs an interactive session to help users get started
    func runInteractive() async throws {
        let noora = Noora()
        
        // Show the ASCII art first
        print(Banner.make())
        print()
        
        // Welcome message
        print("👋 Welcome to Spex!".bold)
        print("   Your AI-powered data pipeline generator\n".dim)
        
        // Check if there's already a spec.toml in the current directory
        let fileManager = FileManager.default
        let currentDir = fileManager.currentDirectoryPath
        let specPath = "\(currentDir)/spec.toml"
        let hasExistingSpec = fileManager.fileExists(atPath: specPath)
        
        // Ask what they want to do
        let startProject = noora.singleChoicePrompt(
            title: "Getting Started",
            question: hasExistingSpec ? 
                "Found an existing spec.toml in this directory. What would you like to do?" :
                "Would you like to start a new project?",
            options: hasExistingSpec ? 
                ["Use existing spec.toml", "Create new spec.toml", "Exit"] :
                ["Yes", "No"]
        )
        
        if startProject == "No" || startProject == "Exit" {
            print("\n👋 See you later! Run 'spex --help' to see available commands.\n".dim)
            return
        }
        
        if hasExistingSpec && startProject == "Use existing spec.toml" {
            // Proceed with existing spec
            print("\n🚀 Great! Let's generate your pipeline using the existing spec.toml\n".green)
            
            // Create arguments manually without using the Arguments struct
            let args = GenerateCommand.Arguments(spec: specPath, provider: nil, model: nil)
            
            try await runGenerate(args: args)
            return
        }
        
        // If we're here, user wants to create a new spec
        if hasExistingSpec {
            // Ask if they want to overwrite
            let overwrite = noora.singleChoicePrompt(
                title: "Overwrite Confirmation",
                question: "This will overwrite the existing spec.toml. Continue?",
                options: ["Yes, overwrite", "No, cancel"]
            )
            
            if overwrite == "No, cancel" {
                print("\n✅ Cancelled. Your existing spec.toml is unchanged.\n".yellow)
                return
            }
            
            // Delete the existing file
            try? fileManager.removeItem(atPath: specPath)
        }
        
        // Guide them through creating a spec
        print("\n📝 Let's create your spec.toml file!\n".cyan)
        
        // Ask about the type of analysis
        let analysisType = noora.textPrompt(
            title: "Project Setup",
            prompt: "What type of analysis are you building? (e.g., Ad Attribution, User Segmentation, Revenue Analysis)",
            description: "This helps the AI understand your use case"
        )
        
        // Ask about input datasets
        print("\n📊 Now let's define your input datasets.".cyan)
        print("   You'll need at least one dataset to analyze.\n".dim)
        
        var datasets: [(name: String, description: String)] = []
        var addingDatasets = true
        
        while addingDatasets {
            let datasetName = noora.textPrompt(
                title: "Dataset \(datasets.count + 1)",
                prompt: "Dataset name: (e.g., engagements, signups, transactions)"
            )
            
            let datasetDesc = noora.textPrompt(
                prompt: "Brief description: What does this dataset contain?"
            )
            
            datasets.append((name: datasetName, description: datasetDesc))
            
            if datasets.count >= 1 {
                let addMore = noora.singleChoicePrompt(
                    question: "Add another dataset?",
                    options: ["Yes", "No"]
                )
                addingDatasets = (addMore == "Yes")
            }
        }
        
        // Create the spec.toml with user's inputs
        let customSpec = createCustomSpec(
            analysisType: analysisType.isEmpty ? "Ad-Attributed Subscriptions" : analysisType,
            datasets: datasets
        )
        
        // Write the file
        let fileURL = URL(fileURLWithPath: specPath)
        try customSpec.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        
        print("\n✨ Successfully created spec.toml!".green.bold)
        print("   Location: \(specPath.cyan)")
        
        // Ask if they want to generate now
        let generateNow = noora.singleChoicePrompt(
            title: "\nNext Steps",
            question: "Would you like to generate your pipeline now?",
            options: ["Yes, generate now", "No, I'll edit the spec first"]
        )
        
        if generateNow == "Yes, generate now" {
            print("\n🚀 Generating your pipeline...\n".green)
            
            // Create arguments manually without using the Arguments struct
            let args = GenerateCommand.Arguments(spec: specPath, provider: nil, model: nil)
            
            try await runGenerate(args: args)
        } else {
            print("\n✅ Your spec.toml has been created!".green)
            print("\n   Next steps:".bold)
            print("   1. Edit your spec.toml to add sample data paths")
            print("   2. Define any output datasets or metrics")
            print("   3. Run: spex generate --spec spec.toml".cyan)
            print("\n   💡 Tip: Check the examples/ directory for inspiration!\n".dim)
        }
    }
    
    /// Creates a custom spec.toml content based on user inputs
    private func createCustomSpec(analysisType: String, datasets: [(name: String, description: String)]) -> String {
        var spec = """
        # spec.toml
        language = "pyspark"
        analysis_type = "\(analysisType)"
        description = "Analyzes \(datasets.map { $0.name }.joined(separator: ", ")) data for \(analysisType.lowercased())."
        
        """
        
        // Add datasets with better examples based on common patterns
        for (index, dataset) in datasets.enumerated() {
            let exampleData: String
            
            // Provide contextual examples based on dataset name
            if dataset.name.lowercased().contains("event") || dataset.name.lowercased().contains("log") {
                exampleData = """
                user_id,event_type,page_id,timestamp,session_id
                user_001,impression,home_page,2025-01-15T10:00:00Z,session_123
                user_001,click,home_page,2025-01-15T10:00:05Z,session_123
                user_002,impression,product_page,2025-01-15T10:01:00Z,session_124
                """
            } else if dataset.name.lowercased().contains("user") {
                exampleData = """
                user_id,signup_date,plan_type,country
                user_001,2025-01-01,premium,USA
                user_002,2025-01-05,basic,UK
                user_003,2025-01-10,premium,Canada
                """
            } else {
                // Generic example
                exampleData = """
                id,name,value,category
                1,item_a,100,type_1
                2,item_b,200,type_1
                3,item_c,150,type_2
                """
            }
            
            spec += """
            
            [[dataset]]
            name = "\(dataset.name)"
            description = "\(dataset.description)"
            # Option 1: Point to your actual data file
            # sample_data_path = "path/to/\(dataset.name).csv"
            
            # Option 2: Provide inline sample data (recommended for quick start)
            sample_data_block = \"\"\"
            \(exampleData)
            \"\"\"
            
            """
        }
        
        // Add a sample output dataset with a reasonable example
        spec += """
        
        # Define your expected output dataset(s)
        [[output_dataset]]
        name = "analysis_results"
        description = "Summary results from \(analysisType.lowercased()) analysis"
        sample_data_block = \"\"\"
        metric_name,value,percentage
        total_users,1000,100.0
        active_users,750,75.0
        converted_users,150,15.0
        \"\"\"
        
        # Define metrics to calculate (optional but recommended)
        [[metric]]
        name = "total_count"
        logic = "Count all unique records"
        aggregation = "Count"
        aggregation_field = "id"
        
        [[metric]]
        name = "unique_users"
        logic = "Count distinct users in the dataset"
        aggregation = "CountDistinct"
        aggregation_field = "user_id"
        """
        
        return spec
    }
}