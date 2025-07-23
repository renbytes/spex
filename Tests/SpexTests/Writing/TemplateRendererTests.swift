import XCTest

@testable import Spex

final class TemplateRendererTests: XCTestCase {

    func testRenderComplexTemplateWithLoopsAndVariables() throws {
        let template = """
            # Analysis: {{ spec.analysis_type }}
            ## Metrics
            {% for metric in spec.metrics %}
            - **{{ metric.name }}**: {{ metric.logic }}
            {% endfor %}
            Generated on: {{ timestamp }}
            """

        let context: [String: Any] = [
            "spec": [
                "analysis_type": "Sales Analysis",
                "metrics": [
                    ["name": "total_revenue", "logic": "Sum of all sales"],
                    ["name": "avg_order_value", "logic": "Average order size"],
                ],
            ],
            "timestamp": "2025-07-22",
        ]

        let result = try TemplateRenderer.render(template: template, context: context)

        let expected = """
            # Analysis: Sales Analysis
            ## Metrics

            - **total_revenue**: Sum of all sales

            - **avg_order_value**: Average order size

            Generated on: 2025-07-22
            """

        XCTAssertEqual(
            result.trimmingCharacters(in: .whitespacesAndNewlines),
            expected.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
