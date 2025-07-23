import ArgumentParser

/// A command to create a default `spec.toml` file in the current directory.
struct InitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a default spec.toml file in the current directory."
    )

    /// The main execution method for the command. It delegates the core logic
    /// to the `AppOrchestrator`.
    func run() async throws { 
        let orchestrator = AppOrchestrator()
        try await orchestrator.runInit()
    }
}

/// A command to generate a new analytics pipeline from a specification file.
struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a new analytics pipeline from a specification.",
        discussion: """
            This command reads a spec.toml file and generates a complete, production-ready
            data analysis pipeline in your chosen language (Python, PySpark, or SQL).
            
            Example:
                spex generate --spec myproject.toml --provider openai
            """
    )

    @OptionGroup
    var arguments: Arguments

    /// The main execution method for the command. It delegates the core logic
    /// to the `AppOrchestrator`.
    func run() async throws {
        let orchestrator = AppOrchestrator()
        try await orchestrator.runGenerate(args: arguments)
    }
}