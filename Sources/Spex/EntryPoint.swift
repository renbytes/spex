import ArgumentParser
import Vapor
import DotEnv

/// Root command that exposes all Spex sub‑commands.
struct Spex: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A spec‑driven data‑science pipeline generator powered by large language models.",
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
    static func main() async throws {
        if let spexRoot = ProcessInfo.processInfo.environment["SPEX_ROOT"] {
            FileManager.default.changeCurrentDirectoryPath(spexRoot)
        }
        // 1. Load a .env file (if present) into the process environment.
        //    DotEnv doesn’t offer a zero‑argument static `load()`; instead we read then `load()`.
        let cwd = FileManager.default.currentDirectoryPath
        let envPath = cwd + "/.env"
        if FileManager.default.fileExists(atPath: envPath) {
            var dotenv = try DotEnv.read(path: envPath)
            dotenv.load() // does nothing if keys already exist
        }

        // 2. Detect the runtime environment (parses CLI flags, etc.).
        _ = try Environment.detect()

        // 3. Hand over control to the argument‑parser root command.
        await Spex.main()
    }
}
