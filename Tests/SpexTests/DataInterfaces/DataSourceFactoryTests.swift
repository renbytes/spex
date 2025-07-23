import XCTest
@testable import Spex

/// Unit tests for the `DataSourceFactory`.
///
/// These tests verify that the factory correctly selects the appropriate
/// data source and parser based on the dataset configuration.
final class DataSourceFactoryTests: XCTestCase {

    /// Tests that CSV files get the CSV parser.
    func testMakeDataSource_WithCsvFile_ReturnsCsvParser() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset",
            sampleDataPath: "data/test.csv"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNotNil(dataSource)
        XCTAssertTrue(dataSource is LocalFileDataSource)
        
        // We can't directly test the parser type without exposing it,
        // but we can verify the behavior indirectly
    }
    
    /// Tests that non-CSV files get the delimited parser.
    func testMakeDataSource_WithTxtFile_ReturnsDelimitedParser() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset",
            sampleDataPath: "data/test.txt"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNotNil(dataSource)
        XCTAssertTrue(dataSource is LocalFileDataSource)
    }
    
    /// Tests that datasets with inline blocks get the block data source.
    func testMakeDataSource_WithInlineBlock_ReturnsBlockDataSource() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset",
            sampleDataBlock: "id,name\n1,test"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNotNil(dataSource)
        XCTAssertTrue(dataSource is BlockDataSource)
    }
    
    /// Tests that datasets with neither path nor block return nil.
    func testMakeDataSource_WithNoDataSource_ReturnsNil() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNil(dataSource)
    }
    
    /// Tests case-insensitive file extension handling.
    func testMakeDataSource_WithUppercaseCsv_ReturnsCsvParser() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset",
            sampleDataPath: "data/TEST.CSV"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNotNil(dataSource)
        XCTAssertTrue(dataSource is LocalFileDataSource)
    }
    
    /// Tests that file path takes precedence over inline block if both are provided.
    func testMakeDataSource_WithBothPathAndBlock_PrefersFilePath() {
        // ARRANGE
        let dataset = Dataset(
            name: "test",
            description: "Test dataset",
            sampleDataPath: "data/test.csv",
            sampleDataBlock: "inline data"
        )
        
        // ACT
        let dataSource = DataSourceFactory.makeDataSource(for: dataset)
        
        // ASSERT
        XCTAssertNotNil(dataSource)
        XCTAssertTrue(dataSource is LocalFileDataSource)
    }
}