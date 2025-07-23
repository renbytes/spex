import ArgumentParser
import Vapor
import DotEnv
import Foundation

/// Root command that exposes all Spex sub‐commands.
struct Spex: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spex",
        abstract: "A spec-driven data-science pipeline generator powered by large language models.",
        version: "0.1.0",
        subcommands: [
            GenerateCommand.self,
            InitCommand.self
        ],
        defaultSubcommand: nil
    )
}

/// Application entry‐point.
@main
struct EntryPoint {
    /// The main function is marked `async` to allow awaiting interactive mode, etc.
    static func main() async {
        // --- 1. Pre-emptive Help Check ---
        if CommandLine.arguments.contains("--help") || CommandLine.arguments.contains("-h") {
            HelpGenerator.display()
            Foundation.exit(0)
        }

        // --- 2. If no subcommand/flags, jump straight to interactive mode (no ArgumentParser error) ---
        if CommandLine.arguments.count == 1 {
            await runInteractiveMode()
            return
        }

        // --- 3. Environment Setup ---
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
            Logger.log("During application setup: \(error.localizedDescription)", type: .error)
            Foundation.exit(1)
        }

        // --- 4. Command Execution ---
        do {
            var command = try Spex.parseAsRoot()
            if var asyncCommand = command as? AsyncParsableCommand {
                try await asyncCommand.run()
            } else {
                try command.run()
            }
        } catch {
            // ArgumentParser already printed the message; just exit with that error.
            Spex.exit(withError: error)
        }
    }

    /// Encapsulates the logic for running the interactive mode.
    private static func runInteractiveMode() async {
        do {
            let orchestrator = AppOrchestrator()
            try await orchestrator.runInteractive()
        } catch {
            Logger.log(error.localizedDescription, type: .error)
            Foundation.exit(1)
        }
    }
}