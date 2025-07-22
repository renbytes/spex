import XCTest
@testable import Spex

final class NetworkIntegrationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLProtocol.registerClass(MockURLProtocol.self)
    }

    override func tearDown() {
        super.tearDown()
        URLProtocol.unregisterClass(MockURLProtocol.self)
    }

    func testOpenAIClient_Success() async throws {
        // ARRANGE
        let mockResponseData = """
        {
            "choices": [
                {
                    "message": {
                        "role": "assistant",
                        "content": "This is the generated code."
                    }
                }
            ]
        }
        """.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, mockResponseData)
        }
        
        let settings = Settings.mock()
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: sessionConfig)
        
        let client = try OpenAIClient(settings: settings, urlSession: mockSession)

        // ACT
        let result = try await client.generateCode(prompt: "test prompt", model: "gpt-4o-mini")

        // ASSERT
        XCTAssertEqual(result, "This is the generated code.")
    }
}

// MARK: - Mocking Infrastructure

class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            XCTFail("Received unexpected request with no handler set.")
            return
        }
        
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Required override
    }
}

extension Settings {
    static func mock() -> Settings {
        setenv("OPENAI_API_KEY", "test_api_key", 1)
        setenv("GEMINI_API_KEY", "test_api_key", 1)
        return Settings()
    }
}
