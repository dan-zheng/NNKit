//
//  DSL.swift
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

public typealias Rep<Result> = Expression<Result>

public extension Rep {
    func evaluated() -> Result {
        return evaluated(in: Environment(parent: nil))
    }
}

prefix operator ^

public protocol Stageable {
    static prefix func ^(_ value: Self) -> Rep<Self>
}

public extension Stageable {
    var staged: Rep<Self> {
        return ^self
    }
}

extension Int : Stageable {
    public static prefix func ^ (_ value: Int) -> Rep<Int> {
        return ConstantExpression(value: value)
    }
}

extension Bool : Stageable {
    public static prefix func ^ (_ value: Bool) -> Rep<Bool> {
        return ConstantExpression(value: value)
    }
}

extension Float : Stageable {
    public static prefix func ^ (_ value: Float) -> Rep<Float> {
        return ConstantExpression(value: value)
    }
}

extension Array where Element : Stageable {
    public static prefix func ^ (_ value: [Element]) -> Rep<[Element]> {
        return ConstantExpression(value: value)
    }
}

/// - Note: Special case, we make it such that `Float` can be inferred top-down.
/// Otherwise the type system would infer an array literal of floats as
/// `[Double]`.
public prefix func ^ (_ value: [Float]) -> Rep<[Float]> {
    return ConstantExpression(value: value)
}

public prefix func ^ <T : Stageable>(_ value: [T]) -> Rep<[T]> {
    return ConstantExpression(value: value)
}

public extension Rep where Result : Numeric {
    static func + (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return ArithmeticExpression(operator: .add, left: lhs, right: rhs)
    }

    static func - (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return ArithmeticExpression(operator: .subtract, left: lhs, right: rhs)
    }

    static func * (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return ArithmeticExpression(operator: .multiply, left: lhs, right: rhs)
    }
}

public extension Rep where Result : SignedNumeric {
    static prefix func - (operand: Rep<Result>) -> Rep<Result> {
        return NegateExpression(operand: operand)
    }
}

public extension Rep where Result : Comparable {
    static func > (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .greaterThan,
                                    left: lhs, right: rhs)
    }

    static func >= (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .greaterThanOrEqual,
                                    left: lhs, right: rhs)
    }

    static func < (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .lessThan, left: lhs, right: rhs)
    }

    static func <= (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .lessThanOrEqual,
                                    left: lhs, right: rhs)
    }

    static func == (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .equal, left: lhs, right: rhs)
    }

    static func != (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Bool> {
        return ComparisonExpression(operator: .notEqual, left: lhs, right: rhs)
    }
}

public extension Rep where Result == Bool {
    static func && (lhs: Rep<Bool>, rhs: Rep<Bool>) -> Rep<Bool> {
        return BooleanExpression(operator: .and, left: lhs, right: rhs)
    }

    static func || (lhs: Rep<Bool>, rhs: Rep<Bool>) -> Rep<Bool> {
        return BooleanExpression(operator: .or, left: lhs, right: rhs)
    }

    static prefix func ! (operand: Rep<Bool>) -> Rep<Bool> {
        return LogicalNotExpression(operand: operand)
    }
}

public extension Rep where Result : BinaryInteger {
    static func / (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return IntegerDivisionExpresison(operator: .divide,
                                         left: lhs, right: rhs)
    }

    static func % (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return IntegerDivisionExpresison(operator: .remainder,
                                         left: lhs, right: rhs)
    }
}

public extension Rep where Result : FloatingPoint {
    static func / (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return FloatingPointDivisionExpression(operator: .divide,
                                               left: lhs, right: rhs)
    }

    static func % (lhs: Rep<Result>, rhs: Rep<Result>) -> Rep<Result> {
        return FloatingPointDivisionExpression(operator: .remainder,
                                               left: lhs, right: rhs)
    }
}

public func lambda<Argument, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<Argument>) -> Rep<Result>) -> Rep<(Argument) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    return LambdaExpression(closure: closure, location: loc)
}

public extension Rep {
    subscript<Argument, ClosureResult>(_ arg: Rep<Argument>) -> Rep<ClosureResult>
        where Result == (Argument) -> ClosureResult {
        return ApplyExpression<Argument, ClosureResult>(closure: self, argument: arg)
    }
}

public func `if`<Result>(_ condition: Rep<Bool>,
                  then: @autoclosure @escaping () -> Rep<Result>,
                  else: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return IfExpression(condition: condition, then: then(), else: `else`())
}

public func cond<Result>(
    _ cond1: Rep<Bool>, _ then1: @autoclosure @escaping () -> Rep<Result>,
    `else`: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return CondExpression(clauses: [(cond1, then1)], else: `else`)
}

public func cond<Result>(
    _ cond1: Rep<Bool>, _ then1: @autoclosure @escaping () -> Rep<Result>,
    _ cond2: Rep<Bool>, _ then2: @autoclosure @escaping () -> Rep<Result>,
    `else`: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return CondExpression(clauses: [(cond1, then1),
                                    (cond2, then2)],
                          else: `else`)
}

public func cond<Result>(
    _ cond1: Rep<Bool>, _ then1: @autoclosure @escaping () -> Rep<Result>,
    _ cond2: Rep<Bool>, _ then2: @autoclosure @escaping () -> Rep<Result>,
    _ cond3: Rep<Bool>, _ then3: @autoclosure @escaping () -> Rep<Result>,
    `else`: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return CondExpression(clauses: [(cond1, then1),
                                    (cond2, then2),
                                    (cond3, then3)],
                          else: `else`)
}

public func cond<Result>(
    _ cond1: Rep<Bool>, _ then1: @autoclosure @escaping () -> Rep<Result>,
    _ cond2: Rep<Bool>, _ then2: @autoclosure @escaping () -> Rep<Result>,
    _ cond3: Rep<Bool>, _ then3: @autoclosure @escaping () -> Rep<Result>,
    _ cond4: Rep<Bool>, _ then4: @autoclosure @escaping () -> Rep<Result>,
    `else`: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return CondExpression(clauses: [(cond1, then1),
                                    (cond2, then2),
                                    (cond3, then3),
                                    (cond4, then4)],
                          else: `else`)
}

public func cond<Result>(
    _ cond1: Rep<Bool>, _ then1: @autoclosure @escaping () -> Rep<Result>,
    _ cond2: Rep<Bool>, _ then2: @autoclosure @escaping () -> Rep<Result>,
    _ cond3: Rep<Bool>, _ then3: @autoclosure @escaping () -> Rep<Result>,
    _ cond4: Rep<Bool>, _ then4: @autoclosure @escaping () -> Rep<Result>,
    _ cond5: Rep<Bool>, _ then5: @autoclosure @escaping () -> Rep<Result>,
    `else`: @autoclosure @escaping () -> Rep<Result>) -> Rep<Result> {
    return CondExpression(clauses: [(cond1, then1),
                                    (cond2, then2),
                                    (cond3, then3),
                                    (cond4, then4),
                                    (cond5, then5)],
                          else: `else`)
}

public extension Rep {
    func map<Argument, MapResult>(_ fn: Rep<(Argument) -> MapResult>) -> Rep<[MapResult]>
        where Result == [Argument] {
        return MapExpression(functor: fn, array: self)
    }

    func map<Argument, MapResult>(_ fn: @escaping (Rep<Argument>) -> Rep<MapResult>) -> Rep<[MapResult]>
        where Result == [Argument] {
        return map(lambda(fn))
    }

    func reduce<Argument, ReductionResult>(
        _ initial: Rep<ReductionResult>,
        _ combiner: Rep<((ReductionResult, Argument)) -> ReductionResult>) -> Rep<ReductionResult>
        where Result == [Argument] {
        return ReduceExpression(initial: initial, combiner: combiner, array: self)
    }

    func reduce<Argument, ReductionResult>(
        _ initial: Rep<ReductionResult>,
        _ combiner: @escaping (Rep<(ReductionResult, Argument)>) -> Rep<ReductionResult>) -> Rep<ReductionResult>
        where Result == [Argument] {
        return reduce(initial, lambda(combiner))
    }
}
