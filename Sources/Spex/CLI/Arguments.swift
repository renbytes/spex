import ArgumentParser

extension GenerateCommand {
    /// A struct that encapsulates all arguments for the `generate` subcommand.
    /// This mirrors the structure of the Rust `GenerateArgs` struct.
    struct Arguments: ParsableArguments {
        
        // --- Specification Source ---
        
        /// Path to a `spec.toml` file. If used, all other flags are ignored.
        @Option(name:.long, help: "Path to a spec.toml file containing the analysis specification.")
        var spec: String
        
        // --- LLM Provider and Model Selection ---
        
        /// The LLM provider to use for code generation.
        @Option(name:.long, help: "The LLM provider to use for code generation (e.g., openai, gemini).")
        var provider: LlmProvider?
        
        /// The specific model to use (e.g., gpt-4o-mini, gemini-1.5-flash).
        @Option(name:.long, help: "The specific LLM model to use for generation.")
        var model: String?
        
        /// Default initializer required by ArgumentParser
        init() {}
        
        /// Memberwise initializer for programmatic creation
        init(spec: String, provider: LlmProvider? = nil, model: String? = nil) {
            self.spec = spec
            self.provider = provider
            self.model = model
        }
    }
}