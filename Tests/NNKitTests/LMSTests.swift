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

    func testArith() {
        let x = ^10
        XCTAssertEqual((x + 10).!, 20)
    }

    func testFuncApp() {
        let giveOne = lambda { ^1 }
        XCTAssertEqual(giveOne[].!, 1)
        let f = giveOne.!
        XCTAssertEqual(f(), 1)
    }

    func testTuple() {
        let perceptron = lambda { (w: Rep<Float>, x: Rep<Float>, b: Rep<Float>) in
            w * x + b
        }
        let result = perceptron[^0.8, ^1.0, ^0.4].!
        XCTAssertEqual(result, 1.2)
    }

    func testIndirectRecursion() {
        func fac(_ n: Rep<Int>) -> Rep<Int> {
            return .if(n == 0, then: ^1, else: n * lambda(fac)[n-1])
        }
        let result = fac(^5).!
        XCTAssertEqual(result, 120)
    }

    func testResultCaching() {
        let sumTimes10: Rep<(Int, Int) -> (Int) -> Int> =
            lambda { x, y in lambda { z in (x + y + z) * ^10 } }
        XCTAssertFalse(sumTimes10.shouldInvalidateCache)
        let expr = sumTimes10 as! LambdaExpression<(Int, Int), (Int) -> Int>
        XCTAssertTrue(expr.closure.body.shouldInvalidateCache)
        let innerLambda = sumTimes10[^3, ^4]
        XCTAssertFalse(innerLambda.shouldInvalidateCache)
        let prod = innerLambda[^5]
        XCTAssertEqual(prod.!, 120)
        XCTAssertEqual(prod.!, 120)
        let prod2 = sumTimes10[^1, ^2][prod]
        XCTAssertEqual(prod2.!, 1230)
        XCTAssertEqual(prod2.!, 1230)
        XCTAssertEqual(prod.!, 120)
        XCTAssertEqual(prod2.!, 1230)
    }

    func testCond() {
        func fib(_ n: Rep<Int>) -> Rep<Int> {
            let next = lambda { n in fib(n - 1) + fib(n - 2) }
            return cond(n == 0, ^0,
                        n == 1, ^1,
                        n > 1, next[n],
                        else: next[n])
        }
        let f5 = fib(^5)
        XCTAssertEqual(f5.!, 5)
        XCTAssertEqual(f5.!, 5)
        let f12 = lambda(fib)[f5 + 7]
        XCTAssertEqual(f12.!, 144)
        XCTAssertEqual(f12.!, 144)
    }

    func testHOF() {
        /// Collections
        let array = ^[1.0, 2.0, 3.0, 4.0]
        let sum = array.reduce(0, +)
        XCTAssertEqual(sum.!, 10)
        let product = array.reduce(1, *)
        XCTAssertEqual(product.!, 24)
        let incrBySum = array.map { $0 + sum }
        XCTAssertEqual(incrBySum.!, [11, 12, 13, 14])
        let odds = array.filter { $0 % 2 != 0 }
        XCTAssertEqual(odds.!, [1, 3])
        let zipped = zip(array, incrBySum)
        XCTAssert((zipped.!).elementsEqual(
            [(1, 11), (2, 12), (3, 13), (4, 14)], by: ==))
        let zippedWith = zip(array, incrBySum, with: -)
        XCTAssert((zippedWith.!).elementsEqual(
            [-10, -10, -10, -10], by: ==))
        /// Currying
        let ten = ^10
        let add: Rep<(Int, Int) -> Int> = lambda(+)
        let curry = lambda { (f: Rep<(Int, Int) -> Int>) in
            lambda { x in
                lambda { y in
                    f[x, y]
                }
            }
        }
        let curryAdd = curry[add]
        let addTen = curryAdd[ten]
        let twentyFive = addTen[^15]
        XCTAssertEqual(twentyFive.!, 25)
        /// Y combinator
        let fac: Rep<(Int) -> Int> = fix { f in
            lambda { (n: Rep<Int>) in
                .if(n == 0, then: ^1, else: n * f[n - 1])
            }
        }
        let fib: Rep<(Int) -> Int> = fix { f in
            lambda { (n: Rep<Int>) in
                .if(n == 0,
                    then: ^0,
                    else: .if(n == 1,
                              then: ^1,
                              else: f[n-1] + f[n-2]))
            }
        }
        XCTAssertEqual(fac[^5].!, 120)
        XCTAssertEqual(fib[^5].!, 5)
    }

    static var allTests : [(String, (LMSTests) -> () throws -> Void)] {
        return [
            ("testArith", testArith),
            ("testFuncApp", testFuncApp),
            ("testTuple", testTuple),
            ("testIndirectRecursion", testIndirectRecursion),
            ("testResultCaching", testResultCaching),
            ("testCond", testCond),
            ("testHOF", testHOF)
        ]
    }

}
