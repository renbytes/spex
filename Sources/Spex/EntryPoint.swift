import ArgumentParser
import Vapor
import DotEnv
import Foundation

/// Root command that exposes all Spex sub‐commands.
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

/// Application entry‐point.
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
            Logger.log("During application setup: \(error.localizedDescription)", type: .error)
            Foundation.exit(1)
        }

        // --- 2. Check for Interactive Mode ---
        // If the user just types "spex" with no arguments, enter interactive mode
        if CommandLine.arguments.count == 1 {
            do {
                let orchestrator = AppOrchestrator()
                try await orchestrator.runInteractive()
                Foundation.exit(0)
            } catch {
                Logger.log(error.localizedDescription, type: .error)
                Foundation.exit(1)
            }
        }

        // --- 3. Command Parsing ---
        // This block handles parsing errors (e.g., --help, missing arguments).
        var command: ParsableCommand
        do {
            command = try Spex.parseAsRoot()
        } catch {
            // A parsing error occurred. Print the banner first.
            print(Banner.make())
            print()
            
            // Then, let ArgumentParser handle printing the specific error
            // message, help text, and exiting.
            Spex.exit(withError: error)
        }

        // --- 4. Command Execution ---
        // This block handles runtime errors from our application logic (e.g., AppError).
        do {
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            // A runtime error occurred. Use our custom logger to print a colored message.
            Logger.log(error.localizedDescription, type: .error)

            // Exit with the appropriate status code.
            let exitCode = Spex.exitCode(for: error)
            Foundation.exit(exitCode.rawValue)
        }
    }
}