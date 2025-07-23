import Foundation

/// A simple template renderer
struct TemplateRenderer {
    
    /// Renders a template string by replacing placeholders with values from context
    /// Supports {{ variable }} syntax similar to Stencil
    static func render(template: String, context: [String: Any]) throws -> String {
        var result = template
        
        // Handle for loops: {% for item in items %}...{% endfor %}
        result = try renderForLoops(in: result, context: context)
        
        // Handle simple variable replacements
        result = renderVariables(in: result, context: context)
        
        return result
    }
    
    /// Renders for loops in the template
    private static func renderForLoops(in template: String, context: [String: Any]) throws -> String {
        var result = template
        
        // Pattern to match {% for item in items %}...{% endfor %}
        let pattern = #"\{%\s*for\s+(\w+)\s+in\s+(\w+(?:\.\w+)*)\s*%\}(.*?)\{%\s*endfor\s*%\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return result
        }
        
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        
        for match in matches.reversed() {
            guard let range = Range(match.range, in: template),
                  let itemNameRange = Range(match.range(at: 1), in: template),
                  let collectionPathRange = Range(match.range(at: 2), in: template),
                  let loopBodyRange = Range(match.range(at: 3), in: template) else { continue }
            
            let itemName = String(template[itemNameRange])
            let collectionPath = String(template[collectionPathRange])
            let loopBody = String(template[loopBodyRange])
            
            // Get the collection from context
            guard let collection = getValue(from: context, keyPath: collectionPath) as? [[String: Any]] else {
                continue
            }
            
            // Render each item
            var renderedItems: [String] = []
            for item in collection {
                var itemContext = context
                itemContext[itemName] = item
                let renderedItem = renderVariables(in: loopBody, context: itemContext)
                renderedItems.append(renderedItem)
            }
            
            result.replaceSubrange(range, with: renderedItems.joined())
        }
        
        return result
    }
    
    /// Renders variable placeholders in the template
    private static func renderVariables(in template: String, context: [String: Any]) -> String {
        var result = template
        
        // Pattern to match {{ variable }} or {{ variable.property }}
        let pattern = #"\{\{\s*([^}]+)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return result
        }
        
        let matches = regex.matches(in: template, range: NSRange(template.startIndex..., in: template))
        
        for match in matches.reversed() {
            guard let range = Range(match.range, in: template),
                  let keyRange = Range(match.range(at: 1), in: template) else { continue }
            
            let keyPath = String(template[keyRange]).trimmingCharacters(in: .whitespaces)
            
            if let value = getValue(from: context, keyPath: keyPath) {
                result.replaceSubrange(range, with: String(describing: value))
            }
        }
        
        return result
    }
    
    /// Gets a value from the context using a dot-notation key path
    private static func getValue(from context: [String: Any], keyPath: String) -> Any? {
        let components = keyPath.split(separator: ".").map(String.init)
        var current: Any? = context
        
        for component in components {
            if let dict = current as? [String: Any] {
                current = dict[component]
            } else {
                return nil
            }
        }
        
        return current
    }

    /// Converts a Specification object to a context dictionary suitable for template rendering.
    /// This is a necessary step before calling the `render` function.
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
