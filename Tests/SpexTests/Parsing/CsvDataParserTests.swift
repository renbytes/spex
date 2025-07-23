import XCTest
@testable import Spex

final class CsvDataParserTests: XCTestCase {
    private var parser: CsvDataParser!

    override func setUp() {
        super.setUp()
        parser = CsvDataParser()
    }

    /// Tests that a standard, well-formed CSV string is parsed correctly.
    func testParse_WithValidCsv_Succeeds() {
        // ARRANGE
        let csvString = """
        id,name,value
        1,alpha,100
        2,beta,200
        """

        // ACT
        let result = parser.parse(from: csvString)

        // ASSERT
        XCTAssertNotNil(result, "Parser should successfully parse valid CSV.")
        XCTAssertEqual(result?.header, ["id", "name", "value"])
        XCTAssertEqual(result?.rows.count, 2)
        XCTAssertEqual(result?.rows[0], ["1", "alpha", "100"])
        XCTAssertEqual(result?.rows[1], ["2", "beta", "200"])
    }

    /// Tests that a malformed CSV (e.g., inconsistent number of columns) fails parsing.
    func testParse_WithMalformedCsv_ReturnsNil() {
        // ARRANGE
        let malformedString = "header1,header2\nvalue1"

        // ACT
        let result = parser.parse(from: malformedString)

        // ASSERT
        XCTAssertNil(result, "Parser should return nil for malformed CSV content.")
    }

    /// Tests that an empty string input results in a nil output.
    func testParse_WithEmptyString_ReturnsNil() {
        // ARRANGE
        let emptyString = ""
        
        // ACT
        let result = parser.parse(from: emptyString)

        // ASSERT
        XCTAssertNil(result, "Parser should return nil for an empty string.")
    }
}