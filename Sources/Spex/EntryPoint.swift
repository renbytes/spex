import ArgumentParser
import Vapor
import DotEnv

/// Root command that exposes all Spex sub‑commands.
struct Spex: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        // The abstract is a single-line summary that appears in the OVERVIEW section.
        abstract: "A spec-driven data-science pipeline generator powered by large language models.",
        subcommands: [
            InitCommand.self
            GenerateCommand.self,
        ],
        defaultSubcommand: GenerateCommand.self
    )
}

/// Application entry‑point.
@main
struct EntryPoint {
    static func main() async throws {
        if let spexRoot = ProcessInfo.processInfo.environment["SPEX_ROOT"] {
            FileManager.default.changeCurrentDirectoryPath(spexRoot)
        }
        // 1. Load a .env file (if present) into the process environment.
        let cwd = FileManager.default.currentDirectoryPath
        let envPath = cwd + "/.env"
        if FileManager.default.fileExists(atPath: envPath) {
            let dotenv = try DotEnv.read(path: envPath)
            dotenv.load() // does nothing if keys already exist
        }

        // 2. Detect the runtime environment.
        _ = try Environment.detect()

        // 3. Manually parse arguments to customize help output.
        // This allows us to print a banner before the standard help message.
        do {
            var command = try Spex.parseAsRoot()
            // If parsing succeeds and it's not a help request, run the command.
            try await command.run()
        } catch {
            // Any error caught here that ArgumentParser will handle by printing help
            // should be preceded by our banner. This includes validation errors (like
            // missing arguments) and explicit help requests.
            print(Banner.make())
            print() // Add a newline for spacing.

            // Let ArgumentParser handle printing the appropriate error message,
            // help text, and exiting with the correct code.
            Spex.exit(withError: error)
        }
    }
}
