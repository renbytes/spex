import XCTest
@testable import Spex

final class IdentityParserTests: XCTestCase {
    
    /// Verifies that the IdentityParser always returns nil, regardless of input.
    /// This confirms its behavior as a "pass-through" parser that signals
    /// that no parsing should occur.
    func testParse_AlwaysReturnsNil() {
        // ARRANGE
        let parser = IdentityParser()
        let anyInputString = "This could be any string: csv, table, or plain text."
        let emptyString = ""

        // ACT
        let resultWithContent = parser.parse(from: anyInputString)
        let resultWithEmpty = parser.parse(from: emptyString)

        // ASSERT
        XCTAssertNil(resultWithContent, "IdentityParser should return nil even with content.")
        XCTAssertNil(resultWithEmpty, "IdentityParser should return nil for an empty string.")
    }
}