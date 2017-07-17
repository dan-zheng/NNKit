import XCTest
@testable import nn_dsl

class nn_dslTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        XCTAssertEqual(nn_dsl().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
