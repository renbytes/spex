import Foundation
import Rainbow

/// A utility for generating and displaying a custom, formatted help screen.
struct HelpGenerator {

    static func display() {
        // 1. Banner
        print(Banner.make().cyan)
        print()

        // 2. Tagline
        print("A spec-driven data-science pipeline generator powered by large language models.".bold)
        print()

        // 3. Usage
        sectionTitle("USAGE")
        print("  spex <subcommand> [options]".white)
        print("  (run 'spex' with no subcommand to enter interactive mode)")
        print()

        // 4. Subcommands
        sectionTitle("SUBCOMMANDS")
        let subcommands = [
            ["generate", "Generate a new analytics pipeline from a specification."],
            ["init",     "Create a default spec.toml file in the current directory."]
        ]
        printIndented(table(from: subcommands, padding: 2))
        print()

        // 5. Global Options
        sectionTitle("GLOBAL OPTIONS")
        let options = [
            ["-h, --help", "Show this help information."],
            ["--version",  "Show the version of the tool."]
        ]
        printIndented(table(from: options, padding: 2))
        print()

        // 6. Example
        sectionTitle("EXAMPLE")
        print("  spex generate --spec my_project.toml".cyan)
        print()
    }
}

// MARK: - Helpers

private func sectionTitle(_ text: String) {
    print(text.yellow.bold)
}

private func printIndented(_ s: String, indent: String = "  ") {
    let indented = s
        .components(separatedBy: CharacterSet.newlines)
        .map { indent + $0 }
        .joined(separator: "\n")
    print(indented)
}

private func table(from rows: [[String]], padding: Int) -> String {
    guard !rows.isEmpty else { return "" }
    let colCount = rows.map { $0.count }.max() ?? 0
    var widths = Array(repeating: 0, count: colCount)

    for row in rows {
        for (i, cell) in row.enumerated() {
            widths[i] = max(widths[i], cell.visibleLength)
        }
    }

    let lines = rows.map { row -> String in
        row.enumerated().map { (i, cell) in
            cell + String(repeating: " ", count: widths[i] - cell.visibleLength + padding)
        }.joined()
    }

    return lines.joined(separator: "\n")
}

// Rainbow adds ANSI sequences; strip them when measuring visible width.
private extension String {
    var visibleLength: Int {
        // Basic ANSI escape sequence stripper
        let pattern = "\u{001B}\\[[0-9;]*m"
        return self.replacingOccurrences(of: pattern, with: "", options: .regularExpression).count
    }
}