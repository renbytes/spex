import XCTest
@testable import Spex

final class SparkAsciiDataParserTests: XCTestCase {
    private var parser: SparkAsciiDataParser!

    override func setUp() {
        super.setUp()
        parser = SparkAsciiDataParser()
    }

    /// Tests parsing a standard, well-formed ASCII table.
    func testParse_WithStandardTable_Succeeds() {
        // ARRANGE
        let tableString = """
        +-------+---+----------------+
        | name  |age| role           |
        +-------+---+----------------+
        | Alice | 29| Data Scientist |
        | Bob   | 35| Engineer       |
        +-------+---+----------------+
        """

        // ACT
        let result = parser.parse(from: tableString)

        // ASSERT
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.header, ["name", "age", "role"])
        XCTAssertEqual(result?.rows.count, 2)
        XCTAssertEqual(result?.rows[0], ["Alice", "29", "Data Scientist"])
        XCTAssertEqual(result?.rows[1], ["Bob", "35", "Engineer"])
    }

    /// Tests that extra whitespace within cells is correctly trimmed.
    func testParse_WithExtraWhitespace_Succeeds() {
        // ARRANGE
        let tableString = "|  name   |   age |"

        // ACT
        let result = parser.parse(from: tableString)

        // ASSERT
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.header, ["name", "age"])
        XCTAssertTrue(result?.rows.isEmpty ?? false)
    }

    /// Tests that a string without the characteristic '|' prefix is ignored.
    func testParse_WithNonTableString_ReturnsNil() {
        // ARRANGE
        let nonTableString = "This is just a regular sentence."
        
        // ACT
        let result = parser.parse(from: nonTableString)

        // ASSERT
        XCTAssertNil(result)
    }

    /// Tests that an empty string returns nil.
    func testParse_WithEmptyString_ReturnsNil() {
        // ACT
        let result = parser.parse(from: "")

        // ASSERT
        XCTAssertNil(result)
    }
}