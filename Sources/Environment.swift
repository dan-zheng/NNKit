//
//  Environment.swift
//  NNKit
//
//  Copyright 2017 Richard Wei.
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

/// Source location used to approximate funciton's intentional equivalence
struct SourceLocation : Hashable {
    var file: StaticString
    var line: UInt
    var column: UInt

    static func ==(lhs: SourceLocation, rhs: SourceLocation) -> Bool {
        return lhs.file.utf8Start == rhs.file.utf8Start
            && lhs.line == rhs.line
            && lhs.column == rhs.column
    }

    var hashValue: Int {
        return file.utf8Start.hashValue ^ line.hashValue ^ column.hashValue
    }
}

/// Closure instance to be stored globally
struct Closure<Return> {
    var formal: UInt
    var body: Expression<Return>
}

class Environment {
    /// Tracks global symbol count
    private static var count: UInt = 0
    /// Maps symbols onto values
    private var symbolTable: [UInt : Any] = [:]
    /// Tracks global closure instances via static source location
    private static var closureInstances: [SourceLocation : Any] = [:]
    /// Parent environment in the call graph
    weak var parent: Environment?

    init(parent: Environment?) {
        self.parent = parent
    }

    func value<T>(for symbol: UInt) -> T? {
        return symbolTable[symbol].map { $0 as! T }
            ?? parent?.value(for: symbol)
    }

    func insert<T>(_ value: T, for symbol: UInt) {
        symbolTable[symbol] = value
    }

    static func closure<T>(at location: SourceLocation) -> Closure<T>? {
        return closureInstances[location].map { $0 as! Closure<T> }
    }

    static func registerClosure<T>(_ closure: Closure<T>,
                                   at location: SourceLocation) {
        closureInstances[location] = closure
    }

    static func makeSymbol() -> UInt {
        defer { count += 1 }
        return count
    }
}
