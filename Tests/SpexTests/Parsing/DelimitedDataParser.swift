import XCTest

@testable import Spex

final class DelimitedDataParserTests: XCTestCase {
    private var parser: DelimitedDataParser!

    override func setUp() {
        super.setUp()
        parser = DelimitedDataParser()
    }

    /// Tests parsing where the first column contains spaces, a key feature of this parser.
    func testParse_WithTimestampData_Succeeds() {
        // ARRANGE
        let inputText = """
            snapped_at              price   market_cap    total_volume
            2013-12-27 00:00:00 UTC 734.27  8944473292.0  62881800.0
            2013-12-28 00:00:00 UTC 738.81  9002769255.0  28121600.0
            """

        // ACT
        let result = parser.parse(from: inputText)

        // ASSERT
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.header, ["snapped_at", "price", "market_cap", "total_volume"])
        XCTAssertEqual(result?.rows.count, 2)
        XCTAssertEqual(result?.rows[0], ["2013-12-27 00:00:00 UTC", "734.27", "8944473292.0", "62881800.0"])
        XCTAssertEqual(result?.rows[1], ["2013-12-28 00:00:00 UTC", "738.81", "9002769255.0", "28121600.0"])
    }

    /// Tests parsing with simple, space-separated data.
    func testParse_WithSimpleData_Succeeds() {
        // ARRANGE
        let inputText = """
            name age team
            Alice 29  Blue
            Bob   35  Red
            """

        // ACT
        let result = parser.parse(from: inputText)

        // ASSERT
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.header, ["name", "age", "team"])
        XCTAssertEqual(result?.rows.count, 2)
        XCTAssertEqual(result?.rows[0], ["Alice", "29", "Blue"])
        XCTAssertEqual(result?.rows[1], ["Bob", "35", "Red"])
    }

    /// Tests that the parser fails when a row has fewer columns than the header.
    func testParse_WithRaggedData_ReturnsNil() {
        // ARRANGE
        let inputText = """
            col1 col2 col3
            a    b    c
            d    e
            """

        // ACT
        let result = parser.parse(from: inputText)

        // ASSERT
        XCTAssertNil(result, "Parser should fail for rows with incorrect column counts.")
    }

    /// Tests that an empty input string correctly returns nil.
    func testParse_WithEmptyInput_ReturnsNil() {
        // ACT
        let result = parser.parse(from: "")

        // ASSERT
        XCTAssertNil(result)
    }
}
