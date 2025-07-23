import Foundation
import Progress
import Rainbow
import Table

/// A component responsible for writing generated code and project infrastructure to the filesystem.
///
/// The `CodeWriter` takes the raw string output from the LLM, parses it into individual
/// file blocks, and creates a complete, well-structured project directory. It also generates
/// supporting files like `README.md` and `Makefile` using templates.
struct CodeWriter {

  // MARK: Properties

  private let baseDirectory: URL
  private let fileManager: FileManager
  private let configManager: ConfigManager

  // MARK: Initialization

  /// Creates a new `CodeWriter`.
  /// - Parameter baseDirectory: The root directory where the `generated_jobs` folder will be created. Defaults to the current working directory.
  /// - Parameter fileManager: The file manager instance to use. Defaults to `FileManager.default`.
  init(
    baseDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
    fileManager: FileManager = .default
  ) throws {
    self.baseDirectory = baseDirectory
    self.fileManager = fileManager
    self.configManager = try ConfigManager()
  }

  // MARK: Public Methods

  /// The main method to write all project files.
  ///
  /// This function orchestrates the entire writing process:
  /// 1. Creates the nested output directory for the new project.
  /// 2. Saves the raw LLM output to a log file for debugging.
  /// 3. Parses the raw output and writes each code file, showing a progress bar.
  /// 4. Creates additional project infrastructure (Makefiles, READMEs, etc.).
  /// 5. Prints a summary table and helpful next steps to the console.
  ///
  /// - Parameters:
  ///   - rawOutput: The complete string response from the LLM.
  ///   - spec: The `Specification` used for the generation, needed for metadata.
  /// - Throws: An `AppError` if any file or directory operation fails.
  /// - Returns: The URL of the final output directory.
  func writeFiles(rawOutput: String, spec: Specification) throws -> URL {
    let outputDir = try createOutputDirectory(for: spec)

    try writeRawOutputLog(rawOutput, to: outputDir)
    let generatedFiles = try parseAndWriteFiles(rawOutput, to: outputDir)
    let infraFiles = try createProjectInfrastructure(in: outputDir, for: spec)

    printSummary(
      in: outputDir,
      for: spec,
      generatedFiles: generatedFiles + infraFiles
    )

    return outputDir
  }

  // MARK: Private: Directory and File Creation

  /// Creates the full, timestamped output directory for the generated project.
  private func createOutputDirectory(for spec: Specification) throws -> URL {
    let timestamp = DateFormatter.yyyyMMddHHmmss.string(from: Date())
    let descriptionSlug = spec.description.slugified

    let outputDir =
      baseDirectory
      .appendingPathComponent("generated_jobs")
      .appendingPathComponent(spec.language.lowercased())
      .appendingPathComponent(spec.analysisType.slugified)
      .appendingPathComponent("\(timestamp)__\(descriptionSlug)")

    do {
      try fileManager.createDirectory(
        at: outputDir, withIntermediateDirectories: true, attributes: nil)
      return outputDir
    } catch {
      throw AppError.fileWriteError(path: outputDir.path, source: error)
    }
  }

  /// Saves the raw, unmodified output from the LLM to a log file for debugging.
  private func writeRawOutputLog(_ rawOutput: String, to outputDir: URL) throws {
    let logURL = outputDir.appendingPathComponent("raw_llm_output.log")
    do {
      try rawOutput.write(to: logURL, atomically: true, encoding: .utf8)
    } catch {
      throw AppError.fileWriteError(path: logURL.path, source: error)
    }
  }

  /// Parses the LLM output containing multiple file blocks and writes each to disk.
  private func parseAndWriteFiles(_ rawOutput: String, to outputDir: URL) throws -> [String] {
    let fileBlocks = rawOutput.components(separatedBy: "### FILE:")
    let writeableBlocks = fileBlocks.filter {
      !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var generatedPaths: [String] = []

    // Fixed API Call: The Progress library wraps an iterable sequence with a simple initializer.
    // We loop through the Progress wrapper which displays the progress bar automatically.
    for block in Progress(writeableBlocks) {
      let lines = block.trimmingCharacters(in: .whitespacesAndNewlines).components(
        separatedBy: .newlines)
      guard let pathLine = lines.first else { continue }

      let relativePath = pathLine.trimmingCharacters(in: .whitespaces)
      guard !relativePath.isEmpty, relativePath.count < 100, !relativePath.contains(" ") else {
        throw AppError.parsingError(
          "Received an invalid file path from the LLM: '\(relativePath)'.")
      }

      let fileURL = outputDir.appendingPathComponent(relativePath)

      let parentDir = fileURL.deletingLastPathComponent()
      try fileManager.createDirectory(
        at: parentDir, withIntermediateDirectories: true, attributes: nil)

      var content = lines.dropFirst().joined(separator: "\n")
      if content.hasPrefix("```") {
        content = String(content.dropFirst(3))
        if let langEnd = content.firstIndex(of: "\n") {
          content = String(content[content.index(after: langEnd)...])
        }
      }
      if content.hasSuffix("```") {
        content = String(content.dropLast(3))
      }

      do {
        try content.trimmingCharacters(in: .whitespacesAndNewlines).write(
          to: fileURL, atomically: true, encoding: .utf8)
        generatedPaths.append(relativePath)
      } catch {
        throw AppError.fileWriteError(path: fileURL.path, source: error)
      }
    }
    return generatedPaths
  }

  // MARK: Private: Project Infrastructure

  /// Creates additional project files like Makefiles, .gitignore, and READMEs.
  private func createProjectInfrastructure(in outputDir: URL, for spec: Specification) throws
    -> [String]
  {
    var createdFiles: [String] = []

    try writeTemplate(name: ".gitignore", content: try configManager.getGitignore(), to: outputDir)
    createdFiles.append(".gitignore")

    if let makefileContent = try? configManager.getMakefile(for: spec.language) {
      try writeTemplate(name: "Makefile", content: makefileContent, to: outputDir)
      createdFiles.append("Makefile")
    }

    if let pyproject = configManager.getPyprojectToml(for: spec.language) {
      try writeTemplate(name: "pyproject.toml", content: pyproject, to: outputDir)
      createdFiles.append("pyproject.toml")
    }

    if let envYml = configManager.getEnvironmentYml(for: spec.language) {
      try writeTemplate(name: "environment.yml", content: envYml, to: outputDir)
      createdFiles.append("environment.yml")
    }

    try createDirectoryStructure(in: outputDir)
    try createProjectReadme(in: outputDir, for: spec)
    createdFiles.append("README.md")

    return createdFiles
  }

  /// Creates the standard directory structure for a data science project.
  private func createDirectoryStructure(in outputDir: URL) throws {
    let directories = [
      "data/raw", "data/processed", "data/external",
      "outputs/reports", "outputs/visualizations", "outputs/models",
      "notebooks", "logs", "scripts",
    ]

    for dir in directories {
      let dirURL = outputDir.appendingPathComponent(dir)
      try fileManager.createDirectory(
        at: dirURL, withIntermediateDirectories: true, attributes: nil)
      let gitkeepURL = dirURL.appendingPathComponent(".gitkeep")
      try "".write(to: gitkeepURL, atomically: true, encoding: .utf8)
    }
  }

  /// Creates a comprehensive project README by rendering a template.
  private func createProjectReadme(in outputDir: URL, for spec: Specification) throws {
    let readmeTemplate = try configManager.getReadmeTemplate()

    let context: [String: Any] = [
      "spec": [
        "analysis_type": spec.analysisType,
        "description": spec.description,
        "language": spec.language,
        "datasets": spec.datasets.map { ["name": $0.name, "description": $0.description] },
        "metrics": spec.metrics.map { ["name": $0.name, "logic": $0.logic] },
      ],
      "project_name": outputDir.lastPathComponent,
      "timestamp": ISO8601DateFormatter().string(from: Date()),
      "setup_instructions": configManager.getReadmeInstructions(
        language: spec.language, instructionType: "setup"),
      "run_instructions": configManager.getReadmeInstructions(
        language: spec.language, instructionType: "run"),
      "main_files": getMainFilesList(for: spec.language),
    ]

    let readmeContent = try TemplateRenderer.render(template: readmeTemplate, context: context)
    try writeTemplate(name: "README.md", content: readmeContent, to: outputDir)
  }

  // MARK: Private Helpers

  /// Helper to write a template file.
  private func writeTemplate(name: String, content: String, to outputDir: URL) throws {
    let fileURL = outputDir.appendingPathComponent(name)
    do {
      try content.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch {
      throw AppError.fileWriteError(path: fileURL.path, source: error)
    }
  }

  /// Provides a string listing the main generated files for the README.
  private func getMainFilesList(for language: String) -> String {
    switch language.lowercased() {
    case "python":
      return
        "├── job.py\n├── functions.py\n├── data_validation.py\n├── visualizations.py\n├── reports.py\n├── dashboard.py\n├── config.py\n├── pyproject.toml\n├── environment.yml"
    case "pyspark":
      return
        "├── job.py\n├── functions.py\n├── data_validation.py\n├── visualizations.py\n├── config.py\n├── pyproject.toml\n├── environment.yml"
    case "sql":
      return "├── models/\n│   ├── job.sql\n│   └── schema.yml\n├── tests/"
    default:
      return "├── job.py\n├── functions.py\n├── pyproject.toml"
    }
  }

  /// Prints the final summary table and next steps to the console.
  private func printSummary(in outputDir: URL, for spec: Specification, generatedFiles: [String]) {
    print("\n" + "Project Summary".bold.underline)

    var tableData: [[String]] = [
      ["Project Name:", outputDir.lastPathComponent],
      ["Language:", spec.language.capitalized],
      ["Analysis Type:", spec.analysisType],
    ]

    let keyFiles = ["README.md", "Makefile", "job.py", "environment.yml", "pyproject.toml"]
    let primaryFiles = generatedFiles.filter { path in
      keyFiles.contains { $0 == URL(fileURLWithPath: path).lastPathComponent }
    }

    if !primaryFiles.isEmpty {
      // Add a separator row manually.
      tableData.append(["──────────────", "────────────────────────────────────────"])
      tableData.append(["Key Files", ""])
      tableData.append(contentsOf: primaryFiles.map { ["✓ " + $0, ""] })
    }

    // Fixed API Call: The Table initializer takes data and returns a table that can be rendered with .table()
    do {
      let table = try Table(data: tableData).table()
      print(table)
    } catch {
      // Fallback to simple printing if table creation fails
      print("Project Details:")
      for row in tableData {
        print("  \(row[0]) \(row[1])")
      }
    }

    printNextSteps(for: spec, in: outputDir)
  }

  /// Prints helpful next steps for the user to the console.
  private func printNextSteps(for spec: Specification, in outputDir: URL) {
    let hasCondaEnv = fileManager.fileExists(
      atPath: outputDir.appendingPathComponent("environment.yml").path)

    print("\n" + "🚀 Next steps:".bold)
    print("   cd \(outputDir.path)")

    if hasCondaEnv {
      let envName =
        spec.language.lowercased() == "pyspark" ? "pyspark-analysis-env" : "data-analysis-env"
      print("   conda env create -f environment.yml")
      print("   conda activate \(envName)")
      print("   pip install -e \".[dev]\"")
    } else {
      print("   make setup              # Set up virtual environment")
    }

    print("   make run                # Run the analysis")
    print("   make test               # Run tests")
    print("\n" + "📖 See README.md for detailed instructions".italic)
  }
}

// MARK: - String Extension for Slugification
extension String {
  /// Converts a string into a URL-friendly "slug".
  fileprivate var slugified: String {
    guard let data = self.data(using: .ascii, allowLossyConversion: true) else {
      return self
    }
    guard let latinString = String(data: data, encoding: .ascii) else {
      return self
    }

    let invalidChars = CharacterSet.alphanumerics.inverted
    let slugParts =
      latinString
      .components(separatedBy: invalidChars)
      .filter { !$0.isEmpty }

    return slugParts.joined(separator: "-").lowercased()
  }
}

// MARK: - DateFormatter Extension
extension DateFormatter {
  /// A date formatter for creating timestamps in directory names (yyyyMMdd-HHmmss format).
  fileprivate static let yyyyMMddHHmmss: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    return formatter
  }()
}
