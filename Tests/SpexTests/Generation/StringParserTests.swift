import XCTest
@testable import Spex

final class StringParserTests: XCTestCase {
    
    /// This test confirms that the Specification object can be correctly
    /// converted into a dictionary for use in template rendering.
    func testSpecificationToContext() throws {
        // ARRANGE
        // Use the convenience initializer we created for the Dataset struct.
        let spec = Specification(
            language: "swift",
            analysisType: "test",
            description: "Test description",
            datasets: [
                Dataset(
                    name: "test_data",
                    description: "Test dataset",
                    sampleDataPath: "/path/to/data",
                    dbConnection: nil,
                    schemaOrSample: "id,name"
                )
            ],
            metrics: [
                Metric(
                    name: "count",
                    logic: "Count all",
                    aggregation: .count,
                    aggregationField: "id"
                )
            ]
        )
        
        // ACT
        let context = try StringParser.specificationToContext(spec)
        
        // ASSERT
        XCTAssertNotNil(context["spec"], "The context dictionary should contain a 'spec' key.")
        
        guard let specDict = context["spec"] as? [String: Any] else {
            XCTFail("The value for 'spec' should be a dictionary.")
            return
        }
        
        XCTAssertEqual(specDict["language"] as? String, "swift")
        XCTAssertNotNil(specDict["datasets"], "The spec dictionary should contain a 'datasets' key.")
        XCTAssertNotNil(specDict["metrics"], "The spec dictionary should contain a 'metrics' key.")
    }
}
