import ArgumentParser

/// A command to generate a new analytics pipeline from a specification file.
struct GenerateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate a new analytics pipeline from a specification."
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

/// A command to create a default `spec.toml` file in the current directory.
struct InitCommand: AsyncParsableCommand { // Changed to AsyncParsableCommand
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create a default spec.toml file in the current directory."
    )

    /// The main execution method for the command. It delegates the core logic
    /// to the `AppOrchestrator`.
    func run() async throws { // Added 'async' keyword
        let orchestrator = AppOrchestrator()
        try await orchestrator.runInit() // Added 'await' keyword
    }
}
