import Foundation

/// A simple template engine that replaces placeholders in templates with values from a context dictionary.
struct StringParser {
    
    /// Renders a template string by replacing placeholders with values from the context.
    /// Supports nested key paths like {{ spec.language }} or {{ spec.datasets[0].name }}
    ///
    /// - Parameters:
    ///   - template: The template string containing {{ placeholders }}
    ///   - context: Dictionary containing the values to substitute
    /// - Returns: The rendered string with placeholders replaced
    static func render(template: String, context: [String: Any]) -> String {
        var result = template
        
        // Find all {{ variable }} patterns and replace them
        let pattern = #"\{\{\s*([^}]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return template
        }
        
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        
        // Process matches in reverse order to maintain string indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: template),
                  let keyRange = Range(match.range(at: 1), in: template) else { continue }
            
            let keyPath = String(template[keyRange]).trimmingCharacters(in: .whitespaces)
            
            if let value = getValue(from: context, keyPath: keyPath) {
                result.replaceSubrange(range, with: formatValue(value))
            }
        }
        
        return result
    }
    
    /// Extracts a value from a nested dictionary using a dot-notation key path.
    /// - Parameters:
    ///   - context: The root dictionary
    ///   - keyPath: The key path (e.g., "spec.language" or "spec.datasets")
    /// - Returns: The value if found, nil otherwise
    private static func getValue(from context: [String: Any], keyPath: String) -> Any? {
        let components = keyPath.split(separator: ".").map(String.init)
        var current: Any? = context
        
        for component in components {
            // Handle array indices like datasets[0]
            if component.contains("[") && component.contains("]") {
                let parts = component.split(separator: "[")
                guard parts.count == 2,
                      let arrayKey = parts.first.map(String.init),
                      let indexStr = parts[1].split(separator: "]").first,
                      let index = Int(indexStr) else {
                    return nil
                }
                
                if let dict = current as? [String: Any],
                   let array = dict[arrayKey] as? [Any],
                   index < array.count {
                    current = array[index]
                } else {
                    return nil
                }
            } else if let dict = current as? [String: Any] {
                current = dict[component]
            } else {
                return nil
            }
        }
        
        return current
    }
    
    /// Formats a value for insertion into the template.
    /// Arrays and dictionaries are formatted as readable strings.
    private static func formatValue(_ value: Any) -> String {
        if let array = value as? [Any] {
            return array.map { formatValue($0) }.joined(separator: ", ")
        } else if let dict = value as? [String: Any] {
            return dict.map { "\($0.key): \(formatValue($0.value))" }.joined(separator: ", ")
        } else {
            return String(describing: value)
        }
    }
    
    /// Converts a Specification object to a context dictionary suitable for template rendering.
    static func specificationToContext(_ spec: Specification) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        
        let data = try encoder.encode(spec)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppError.templateError("Failed to convert specification to dictionary")
        }
        
        return ["spec": json]
    }
}
