# API Reference

This document describes the public APIs and extension points in spex. Use this guide when extending spex with new features, providers, or languages.

## Table of Contents
- [Core Protocols](#core-protocols)
- [Data Models](#data-models)
- [Extension Points](#extension-points)
- [Error Handling](#error-handling)
- [Template System](#template-system)
- [Testing APIs](#testing-apis)

## Core Protocols

### LlmClient

The foundation for all LLM provider integrations.

```swift
protocol LlmClient: Sendable {
    /// Generates code by sending a prompt to the LLM provider
    /// - Parameters:
    ///   - prompt: The complete prompt string containing the code generation request
    ///   - model: The specific model identifier (e.g., "gpt-4o-mini", "gemini-2.0-flash")
    /// - Returns: The raw generated code as a string
    /// - Throws: `AppError.llmError` if the API call fails
    func generateCode(prompt: String, model: String) async throws -> String
}
```

**Implementation Example:**
```swift
final class AnthropicClient: LlmClient {
    private let apiKey: String
    
    init(settings: Settings) throws {
        guard let apiKey = settings.anthropicApiKey else {
            throw AppError.configError("ANTHROPIC_API_KEY not found")
        }
        self.apiKey = apiKey
    }
    
    func generateCode(prompt: String, model: String) async throws -> String {
        // Implementation details...
    }
}
```

### DataSource

Defines how to fetch data from various sources.

```swift
protocol DataSource {
    /// Fetches schema information and sample data for a dataset
    /// - Parameter dataset: The dataset specification from spec.toml
    /// - Returns: A formatted string containing schema and sample rows
    /// - Throws: `AppError` if data cannot be fetched or parsed
    func fetchSchemaAndSample(for dataset: Dataset) async throws -> String
}
```

**Expected Output Format:**
```
Schema: column1, column2, column3
Sample Data:
value1, value2, value3
value4, value5, value6
```

### DataParser

Handles parsing of different data formats.

```swift
typealias ParsedSample = (header: [String], rows: [[String]])

protocol DataParser {
    /// Parses raw string data into structured format
    /// - Parameter rawString: The raw data content
    /// - Returns: Tuple of headers and rows, or nil if parsing fails
    func parse(from rawString: String) -> ParsedSample?
}
```

**Implementation Example:**
```swift
struct JsonDataParser: DataParser {
    func parse(from rawString: String) -> ParsedSample? {
        guard let data = rawString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let firstObject = json.first else { return nil }
        
        let header = Array(firstObject.keys)
        let rows = json.map { obj in
            header.map { key in String(describing: obj[key] ?? "") }
        }
        
        return (header, rows)
    }
}
```

## Data Models

### Specification

The core data model representing a spec.toml file.

```swift
struct Specification: Codable {
    let language: String              // Target language: "python", "pyspark", "sql"
    let analysisType: String         // Type of analysis being performed
    let description: String          // Brief description of the project
    var datasets: [Dataset]          // Input datasets
    let metrics: [Metric]            // Metrics to calculate
    var outputDatasets: [Dataset]?   // Expected output datasets
}
```

### Dataset

Represents an input or output dataset.

```swift
struct Dataset: Codable {
    let name: String                    // Dataset identifier
    let description: String             // What the dataset contains
    let sampleDataPath: String?         // Path to sample file
    let sampleDataBlock: String?        // Inline sample data
    let dbConnection: String?           // Database connection string
    var schemaOrSample: String = ""     // Populated during enrichment
}
```

### Metric

Defines a metric to be calculated.

```swift
struct Metric: Codable {
    let name: String                    // Metric identifier
    let logic: String                   // Business logic description
    let aggregation: Aggregation        // Type of aggregation
    let aggregationField: String        // Field to aggregate on
}

enum Aggregation: String, Codable {
    case count = "Count"
    case countDistinct = "CountDistinct"
    case sum = "Sum"
    case avg = "Avg"
    case min = "Min"
    case max = "Max"
}
```

## Extension Points

### Adding a New LLM Provider

1. **Create the client class:**
```swift
final class YourProviderClient: LlmClient {
    func generateCode(prompt: String, model: String) async throws -> String {
        // Your implementation
    }
}
```

2. **Add to the provider enum:**
```swift
// In CliEnums.swift
enum LlmProvider: String, Codable, CaseIterable {
    case openai
    case gemini
    case yourProvider = "your-provider"
}
```

3. **Update AppOrchestrator:**
```swift
// In AppOrchestrator.swift, runGenerate method
switch provider {
case .yourProvider:
    llmClient = try YourProviderClient(settings: settings)
    // ... other cases
}
```

4. **Add environment variables:**
```swift
// In Settings.swift
let yourProviderApiKey: String?
let yourProviderApiUrl: String
let yourProviderDefaultModel: String
```

### Adding a New Target Language

1. **Create directory structure:**
```
configs/
└── your_language/
    ├── prompt_templates/
    │   └── default.tera
    ├── Makefile.template
    ├── instructions_setup.md
    └── instructions_run.md
```

2. **Add to Language enum:**
```swift
enum Language: String, Codable, CaseIterable {
    case python
    case pyspark
    case sql
    case yourLanguage = "your-language"
}
```

3. **Create prompt template:**
```
You are an expert {{ spec.language }} developer...

Target Language: {{ spec.language }}
Analysis Type: {{ spec.analysis_type }}

{% for dataset in spec.datasets %}
- Dataset: {{ dataset.name }}
  {{ dataset.schema_or_sample }}
{% endfor %}

Generate the following files:
### FILE: main.ext
...
```

### Adding a New Data Parser

1. **Implement the protocol:**
```swift
struct YamlDataParser: DataParser {
    func parse(from rawString: String) -> ParsedSample? {
        // Parse YAML format
        // Return (headers, rows)
    }
}
```

2. **Update DataSourceFactory:**
```swift
// In DataSourceFactory.swift
if path.lowercased().hasSuffix(".yaml") || path.lowercased().hasSuffix(".yml") {
    parser = YamlDataParser()
}
```

### Custom Template Functions

Extend the TemplateRenderer with new functions:

```swift
// In TemplateRenderer.swift
private static func renderCustomFunctions(in template: String, context: [String: Any]) -> String {
    var result = template
    
    // Add custom function: {% uppercase variable %}
    let uppercasePattern = #"\{%\s*uppercase\s+(\w+(?:\.\w+)*)\s*%\}"#
    if let regex = try? NSRegularExpression(pattern: uppercasePattern) {
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        for match in matches.reversed() {
            if let range = Range(match.range, in: template),
               let keyRange = Range(match.range(at: 1), in: template) {
                let keyPath = String(template[keyRange])
                if let value = getValue(from: context, keyPath: keyPath) {
                    result.replaceSubrange(range, with: String(describing: value).uppercased())
                }
            }
        }
    }
    
    return result
}
```

## Error Handling

### AppError

All errors in spex are wrapped in the `AppError` enum:

```swift
enum AppError: Error, LocalizedError {
    case configError(String)         // Configuration/environment issues
    case inputError(String)          // Invalid user input
    case validationError(String)     // Spec validation failures
    case fileReadError(String)       // File system read errors
    case fileWriteError(path: String, source: Error)
    case llmError(String)           // LLM API errors
    case templateError(String)      // Template rendering errors
    case parsingError(String)       // Data parsing errors
}
```

**Best Practices:**
- Always provide actionable error messages
- Include the problematic value in the error
- Suggest fixes when possible

Example:
```swift
throw AppError.validationError(
    """
    Dataset '\(dataset.name)' is missing sample data.
    
    Please add either:
    - sample_data_path = "path/to/data.csv"
    - sample_data_block = \"\"\"
      column1,column2
      value1,value2
      \"\"\"
    """
)
```

## Template System

### Template Context Structure

The context passed to templates has this structure:

```javascript
{
    "spec": {
        "language": "pyspark",
        "analysis_type": "Attribution Analysis",
        "description": "...",
        "datasets": [
            {
                "name": "events",
                "description": "...",
                "schema_or_sample": "..."
            }
        ],
        "metrics": [
            {
                "name": "unique_users",
                "logic": "...",
                "aggregation": "CountDistinct",
                "aggregation_field": "user_id"
            }
        ],
        "output_datasets": [...]
    }
}
```

### Available Template Syntax

```django
{# Comments #}
{# This is a comment and won't appear in output #}

{# Variable substitution #}
{{ spec.language }}
{{ spec.datasets.0.name }}

{# For loops #}
{% for dataset in spec.datasets %}
- Dataset: {{ dataset.name }}
  Description: {{ dataset.description }}
{% endfor %}

{# Nested access #}
{{ spec.metrics.0.aggregation }}
```

### Creating Custom Templates

Place templates in `configs/[language]/prompt_templates/[name].tera`:

```django
{# custom.tera #}
You are an expert {{ spec.language }} developer specializing in {{ spec.analysis_type }}.

Create a data pipeline with these requirements:
{% for metric in spec.metrics %}
- Calculate {{ metric.name }} using {{ metric.aggregation }}
{% endfor %}

### FILE: pipeline.py
# Generated code here...
```

## Testing APIs

### Mock Implementations

Create mocks for testing:

```swift
final actor MockLlmClient: LlmClient {
    var responseToReturn: Result<String, AppError> = .success("mock code")
    private(set) var promptsReceived: [String] = []
    
    func generateCode(prompt: String, model: String) async throws -> String {
        promptsReceived.append(prompt)
        return try responseToReturn.get()
    }
}
```

### Test Helpers

```swift
extension Specification {
    /// Creates a minimal valid specification for testing
    static func testSpec(
        language: String = "python",
        datasets: [Dataset] = []
    ) -> Specification {
        return Specification(
            language: language,
            analysisType: "Test Analysis",
            description: "Test Description",
            datasets: datasets,
            metrics: [
                Metric(
                    name: "test_metric",
                    logic: "Test logic",
                    aggregation: .count,
                    aggregationField: "id"
                )
            ]
        )
    }
}
```

### Integration Test Pattern

```swift
func testEndToEndGeneration() async throws {
    // Arrange
    let tempDir = FileManager.default.temporaryDirectory
    let specPath = tempDir.appendingPathComponent("test.toml")
    try testSpecContent.write(to: specPath, atomically: true, encoding: .utf8)
    
    // Act
    let orchestrator = AppOrchestrator()
    let args = GenerateCommand.Arguments(
        spec: specPath.path,
        provider: .openai,
        model: "gpt-4o-mini"
    )
    try await orchestrator.runGenerate(args: args)
    
    // Assert
    let generatedDir = tempDir.appendingPathComponent("generated_jobs")
    XCTAssertTrue(FileManager.default.fileExists(atPath: generatedDir.path))
}
```

## Best Practices

1. **Protocol Conformance**: Always make protocol implementations `final class` or `struct` for performance
2. **Async/Await**: Use structured concurrency for all I/O operations
3. **Error Messages**: Include specific values and actionable fixes
4. **Testing**: Write tests for all new protocols and implementations
5. **Documentation**: Update this API reference when adding new extension points