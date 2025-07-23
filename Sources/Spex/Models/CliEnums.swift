import ArgumentParser

/// An enum representing the supported target languages for code generation.
/// Conforms to `ExpressibleByArgument` to be used directly as a command-line option.
enum Language: String, Codable, CaseIterable, ExpressibleByArgument {
    case python
    case pyspark
    case sql
}

/// An enum representing the supported aggregation types for metrics.
/// Conforms to `ExpressibleByArgument` to be used directly as a command-line option.
enum Aggregation: String, Codable, CaseIterable, ExpressibleByArgument {
    case count = "Count"
    case countDistinct = "CountDistinct"
    case sum = "Sum"
    case avg = "Avg"
    case min = "Min"
    case max = "Max"
}

/// An enum representing the supported LLM providers.
/// Conforms to `ExpressibleByArgument` to be used directly as a command-line option.
enum LlmProvider: String, Codable, CaseIterable, ExpressibleByArgument {
    case openai
    case gemini
    case internalGw = "internal"
}
