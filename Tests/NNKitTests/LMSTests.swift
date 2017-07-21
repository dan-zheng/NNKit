//
//  LMSTests.swift
//  NNKit
//
//  Copyright 2017 DLVM Team.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
@testable import NNKit

class LMSTests : XCTestCase {

    func testTuple() {
        let perceptron = lambda { (w: Rep<Float>, x: Rep<Float>, b: Rep<Float>) in
            w * x + b
        }
        let result = perceptron[^0.8, ^1.0, ^0.4].evaluated()
        XCTAssertEqual(result, 1.2)
    }

    func testHOF() {
        let array = ^[1.0, 2.0, 3.0, 4.0]
        let sum = array.reduce(^0, +)
        XCTAssertEqual(sum.evaluated(), 10)
        let product = array.reduce(^1, *)
        XCTAssertEqual(product.evaluated(), 24)
        let incrBySum = array.map { $0 + sum }
        XCTAssertEqual(incrBySum.evaluated(), [11, 12, 13, 14])
    }

    static var allTests : [(String, (LMSTests) -> () throws -> Void)] {
        return [
            ("testTuple", testTuple)
        ]
    }

}
