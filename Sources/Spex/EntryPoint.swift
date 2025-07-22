import ArgumentParser
import Vapor
import DotEnv

/// Root command that exposes all Spex sub‑commands.
struct Spex: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        // The abstract is a single-line summary that appears in the OVERVIEW section.
        abstract: "A spec-driven data-science pipeline generator powered by large language models.",
        subcommands: [
            GenerateCommand.self,
            InitCommand.self
        ],
        defaultSubcommand: GenerateCommand.self
    )
}

/// Application entry‑point.
@main
struct EntryPoint {
    static func main() async {
        // --- 1. Environment Setup ---
        do {
            if let spexRoot = ProcessInfo.processInfo.environment["SPEX_ROOT"] {
                FileManager.default.changeCurrentDirectoryPath(spexRoot)
            }
            let cwd = FileManager.default.currentDirectoryPath
            let envPath = cwd + "/.env"
            if FileManager.default.fileExists(atPath: envPath) {
                let dotenv = try DotEnv.read(path: envPath)
                dotenv.load()
            }
            _ = try Environment.detect()
        } catch {
            // If setup fails, print the error and exit.
            print("Error during application setup: \(error.localizedDescription)".red)
            Spex.exit(withError: error)
        }

        // --- 2. Command Parsing ---
        // This block handles parsing errors (e.g., --help, missing arguments).
        // These are the cases where we want to show the banner.
        var command: ParsableCommand
        do {
            command = try Spex.parseAsRoot()
        } catch {
            // A parsing error occurred. Print the banner first.
            print(Banner.make())
            print() // Add a newline for spacing.
            
            // Then, let ArgumentParser handle printing the specific error
            // message, help text, and exiting.
            Spex.exit(withError: error)
        }

        // --- 3. Command Execution ---
        // This block handles runtime errors from our application logic (e.g., AppError).
        // We do NOT want the banner for these errors.
        do {
            // We must check if the parsed command is async and run it accordingly.
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            // A runtime error occurred. Just let ArgumentParser print the error and exit.
            Spex.exit(withError: error)
        }
    }
}
