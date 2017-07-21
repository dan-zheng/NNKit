//
//  DSL.swift
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

// MARK: - Evaluation

public typealias Rep<Result> = Expression<Result>

public extension Rep {
    func evaluated() -> Result {
        return evaluated(in: Environment(parent: nil))
    }
}

// MARK: - Constant staging

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

// MARK: - Arithmetics

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

/// Overload for stageable constants
/// - Todo: To be removed when conditional conformance is supported. That is,
/// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
public extension Rep where Result : Numeric & Stageable {
    static func + (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs + rhs
    }

    static func + (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs + ^rhs
    }

    static func - (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs - rhs
    }

    static func - (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs - ^rhs
    }

    static func * (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs - rhs
    }

    static func * (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs - ^rhs
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

/// Overload for stageable constants
/// - Todo: To be removed when conditional conformance is supported. That is,
/// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
public extension Rep where Result : Comparable & Stageable {
    static func > (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs > rhs
    }

    static func > (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs > ^rhs
    }

    static func >= (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs >= rhs
    }

    static func >= (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs >= ^rhs
    }

    static func < (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs > rhs
    }

    static func < (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs > ^rhs
    }

    static func <= (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs <= rhs
    }

    static func <= (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs <= ^rhs
    }

    static func == (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs == rhs
    }

    static func == (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs == ^rhs
    }

    static func != (lhs: Result, rhs: Rep<Result>) -> Rep<Bool> {
        return ^lhs != rhs
    }

    static func != (lhs: Rep<Result>, rhs: Result) -> Rep<Bool> {
        return lhs != ^rhs
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

/// Overload for stageable constants
/// - Todo: To be removed when conditional conformance is supported. That is,
/// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
public extension Rep where Result == Bool {
    static func && (lhs: Bool, rhs: Rep<Bool>) -> Rep<Bool> {
        return ^lhs && rhs
    }

    static func && (lhs: Rep<Bool>, rhs: Bool) -> Rep<Bool> {
        return lhs && ^rhs
    }

    static func || (lhs: Bool, rhs: Rep<Bool>) -> Rep<Bool> {
        return ^lhs || rhs
    }

    static func || (lhs: Rep<Bool>, rhs: Bool) -> Rep<Bool> {
        return lhs || ^rhs
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

/// Overload for stageable constants
/// - Todo: To be removed when conditional conformance is supported. That is,
/// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
public extension Rep where Result : BinaryInteger & Stageable {
    static func / (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs / rhs
    }

    static func / (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs / ^rhs
    }

    static func % (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs / rhs
    }

    static func % (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs / ^rhs
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

/// Overload for stageable constants
/// - Todo: To be removed when conditional conformance is supported. That is,
/// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
public extension Rep where Result : FloatingPoint & Stageable {
    static func / (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs / rhs
    }

    static func / (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs / ^rhs
    }

    static func % (lhs: Result, rhs: Rep<Result>) -> Rep<Result> {
        return ^lhs / rhs
    }

    static func % (lhs: Rep<Result>, rhs: Result) -> Rep<Result> {
        return lhs / ^rhs
    }
}

// MARK: - Tuples

public func tuple<A, B>(_ a: Rep<A>, _ b: Rep<B>) -> Rep<(A, B)> {
    return TupleExpression(a, b)
}

public func tuple<A, B, C>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>) -> Rep<(A, (B, C))> {
    return TupleExpression(a, TupleExpression(b, c))
}

public func tuple<A, B, C, D>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>
    ) -> Rep<(A, (B, (C, D)))> {
    return TupleExpression(a, TupleExpression(b, TupleExpression(c, d)))
}

public func tuple<A, B, C, D, E>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>
    ) -> Rep<(A, (B, (C, (D, E))))> {
    return TupleExpression(
        a, TupleExpression(b, TupleExpression(c, TupleExpression(d, e))))
}

public func tuple<A, B, C, D, E, F>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>,
    _ f: Rep<F>) -> Rep<(A, (B, (C, (D, (E, F)))))> {
    return TupleExpression(
        a, TupleExpression(
            b, TupleExpression(c, TupleExpression(d, TupleExpression(e, f)))))
}

public func tuple<A, B, C, D, E, F, G>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>,
    _ f: Rep<F>, _ g: Rep<G>) -> Rep<(A, (B, (C, (D, (E, (F, G))))))> {
    return TupleExpression(
        a, TupleExpression(
            b, TupleExpression(
                c, TupleExpression(
                    d, TupleExpression(e, TupleExpression(f, g))))))
}

public func tuple<A, B, C, D, E, F, G, H>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>,
    _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, H)))))))> {
    return TupleExpression(
        a, TupleExpression(
            b, TupleExpression(
                c, TupleExpression(
                    d, TupleExpression(
                        e, TupleExpression(f, TupleExpression(g, h)))))))
}

public func tuple<A, B, C, D, E, F, G, H, I>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>,
    _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>, _ i: Rep<I>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, (H, I))))))))> {
    return TupleExpression(
        a, TupleExpression(
            b, TupleExpression(
                c, TupleExpression(
                    d, TupleExpression(
                        e, TupleExpression(
                            f, TupleExpression(g, TupleExpression(h, i))))))))
}

public func tuple<A, B, C, D, E, F, G, H, I, J>(
    _ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>, _ e: Rep<E>,
    _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>, _ i: Rep<I>, _ j: Rep<J>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, (H, (I, J)))))))))> {
    return TupleExpression(
        a, TupleExpression(
            b, TupleExpression(
                c, TupleExpression(
                    d, TupleExpression(
                        e, TupleExpression(
                            f, TupleExpression(
                                g, TupleExpression(
                                    h, TupleExpression(i, j)))))))))
}

prefix operator *

public prefix func *<A, B>(_ x: Rep<(A, B)>) -> (Rep<A>, Rep<B>) {
    return (TupleExtractFirstExpression(x), TupleExtractSecondExpression(x))
}

public prefix func *<A, B, C>(
    _ x: Rep<(A, (B, C))>) -> (Rep<A>, Rep<B>, Rep<C>) {
    let (a, x) = *x
    let (b, c) = *x
    return (a, b, c)
}

public prefix func *<A, B, C, D>(
    _ x: Rep<(A, (B, (C, D)))>) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>) {
    let (a, b, x) = *x
    let (c, d) = *x
    return (a, b, c, d)
}

public prefix func *<A, B, C, D, E>(
    _ x: Rep<(A, (B, (C, (D, E))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>) {
    let (a, b, c, x) = *x
    let (d, e) = *x
    return (a, b, c, d, e)
}

public prefix func *<A, B, C, D, E, F>(
    _ x: Rep<(A, (B, (C, (D, (E, F)))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>, Rep<F>) {
    let (a, b, c, d, x) = *x
    let (e, f) = *x
    return (a, b, c, d, e, f)
}

public prefix func *<A, B, C, D, E, F, G>(
    _ x: Rep<(A, (B, (C, (D, (E, (F, G))))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>, Rep<F>, Rep<G>) {
    let (a, b, c, d, e, x) = *x
    let (f, g) = *x
    return (a, b, c, d, e, f, g)
}

public prefix func *<A, B, C, D, E, F, G, H>(
    _ x: Rep<(A, (B, (C, (D, (E, (F, (G, H)))))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>, Rep<F>, Rep<G>, Rep<H>) {
    let (a, b, c, d, e, f, x) = *x
    let (g, h) = *x
    return (a, b, c, d, e, f, g, h)
}

public prefix func *<A, B, C, D, E, F, G, H, I>(
    _ x: Rep<(A, (B, (C, (D, (E, (F, (G, (H, I))))))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>,
          Rep<F>, Rep<G>, Rep<H>, Rep<I>)
{
    let (a, b, c, d, e, f, g, x) = *x
    let (h, i) = *x
    return (a, b, c, d, e, f, g, h, i)
}

public prefix func *<A, B, C, D, E, F, G, H, I, J>(
    _ x: Rep<(A, (B, (C, (D, (E, (F, (G, (H, (I, J)))))))))>
    ) -> (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>,
          Rep<F>, Rep<G>, Rep<H>, Rep<I>, Rep<J>)
{
    let (a, b, c, d, e, f, g, h, x) = *x
    let (i, j) = *x
    return (a, b, c, d, e, f, g, h, i, j)
}

// MARK: - Lambda abstraction

public func lambda<Argument, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<Argument>) -> Rep<Result>
    ) -> Rep<(Argument) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    return LambdaExpression(closure: closure, location: loc)
}

public func lambda<A, B, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>) -> Rep<Result>
    ) -> Rep<(A, B) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, B)>) -> Rep<Result> {
        let (a, b) = *x
        return closure(a, b)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>) -> Rep<Result>
    ) -> Rep<(A, (B, C)) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, C))>) -> Rep<Result> {
        let (a, b, c) = *x
        return closure(a, b, c)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, D))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, D)))>) -> Rep<Result> {
        let (a, b, c, d) = *x
        return closure(a, b, c, d)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, E, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, E)))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, E))))>) -> Rep<Result> {
        let (a, b, c, d, e) = *x
        return closure(a, b, c, d, e)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, E, F, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>,
                          Rep<D>, Rep<E>, Rep<F>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, (E, F))))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, (E, F)))))>) -> Rep<Result> {
        let (a, b, c, d, e, f) = *x
        return closure(a, b, c, d, e, f)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, E, F, G, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>,
                          Rep<E>, Rep<F>, Rep<G>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, (E, (F, G)))))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, (E, (F, G))))))>) -> Rep<Result> {
        let (a, b, c, d, e, f, g) = *x
        return closure(a, b, c, d, e, f, g)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, E, F, G, H, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>,
                          Rep<E>, Rep<F>, Rep<G>, Rep<H>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, H))))))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, (E, (F, (G, H)))))))>) -> Rep<Result> {
        let (a, b, c, d, e, f, g, h) = *x
        return closure(a, b, c, d, e, f, g, h)
    }
    return LambdaExpression(closure: f, location: loc)
}

public func lambda<A, B, C, D, E, F, G, H, I, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>, Rep<F>,
                          Rep<G>, Rep<H>, Rep<I>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, (H, I)))))))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, (E, (F, (G, (H, I))))))))>) -> Rep<Result> {
        let (a, b, c, d, e, f, g, h, i) = *x
        return closure(a, b, c, d, e, f, g, h, i)
    }
    return LambdaExpression(closure: f, location: loc)
}

// MARK: - Function application

public func lambda<A, B, C, D, E, F, G, H, I, J, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<A>, Rep<B>, Rep<C>, Rep<D>, Rep<E>, Rep<F>,
                          Rep<G>, Rep<H>, Rep<I>, Rep<J>) -> Rep<Result>
    ) -> Rep<(A, (B, (C, (D, (E, (F, (G, (H, (I, J))))))))) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    func f(_ x: Rep<(A, (B, (C, (D, (E, (F, (G, (H, (I, J)))))))))>
        ) -> Rep<Result> {
        let (a, b, c, d, e, f, g, h, i, j) = *x
        return closure(a, b, c, d, e, f, g, h, i, j)
    }
    return LambdaExpression(closure: f, location: loc)
}

public extension Rep {
    subscript<Argument, ClosureResult>(_ arg: Rep<Argument>)
        -> Rep<ClosureResult>
        where Result == (Argument) -> ClosureResult {
        return ApplyExpression<Argument, ClosureResult>(closure: self,
                                                        argument: arg)
    }

    subscript<A, B, ClosureResult>(_ a: Rep<A>, _ b: Rep<B>) -> Rep<ClosureResult>
        where Result == (A, B) -> ClosureResult
    {
        return ApplyExpression<(A, B), ClosureResult>(
            closure: self,
            argument: tuple(a, b)
        )
    }

    subscript<A, B, C, ClosureResult>(_ a: Rep<A>, _ b: Rep<B>,
                                      _ c: Rep<C>) -> Rep<ClosureResult>
        where Result == (A, (B, C)) -> ClosureResult
    {
        return ApplyExpression<(A, (B, C)), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c)
        )
    }

    subscript<A, B, C, D, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, D))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, D))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d)
        )
    }

    subscript<A, B, C, D, E, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, E)))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, E)))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e)
        )
    }

    subscript<A, B, C, D, E, F, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>, _ f: Rep<F>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, (E, F))))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, (E, F))))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e, f)
        )
    }

    subscript<A, B, C, D, E, F, G, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>, _ f: Rep<F>, _ g: Rep<G>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, (E, (F, G)))))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, (E, (F, G)))))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e, f, g)
        )
    }

    subscript<A, B, C, D, E, F, G, H, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>, _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, (E, (F, (G, H))))))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, (E, (F, (G, H))))))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e, f, g, h)
        )
    }

    subscript<A, B, C, D, E, F, G, H, I, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>, _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>,
         _ i: Rep<I>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, (E, (F, (G, (H, I)))))))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, (E, (F, (G, (H, I)))))))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e, f, g, h, i)
        )
    }

    subscript<A, B, C, D, E, F, G, H, I, J, ClosureResult>
        (_ a: Rep<A>, _ b: Rep<B>, _ c: Rep<C>, _ d: Rep<D>,
         _ e: Rep<E>, _ f: Rep<F>, _ g: Rep<G>, _ h: Rep<H>,
         _ i: Rep<I>, _ j :Rep<J>) -> Rep<ClosureResult>
        where Result == (A, (B, (C, (D, (E, (F, (G, (H, (I, J))))))))) -> ClosureResult
    {
        return ApplyExpression<(A, (B, (C, (D, (E, (F, (G, (H, (I, J))))))))), ClosureResult>(
            closure: self,
            argument: tuple(a, b, c, d, e, f, g, h, i, j)
        )
    }
}

// MARK: - Control flow

public func `if`<Result>(
    _ condition: Rep<Bool>,
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

// MARK: - Higher-order functions

public extension Rep {
    func map<Argument, MapResult>(_ fn: Rep<(Argument) -> MapResult>) -> Rep<[MapResult]>
        where Result == [Argument] {
        return MapExpression(functor: fn, array: self)
    }

    func map<Argument, MapResult>(
        file: StaticString = #file, line: UInt = #line, column: UInt = #column,
        _ fn: @escaping (Rep<Argument>) -> Rep<MapResult>) -> Rep<[MapResult]>
        where Result == [Argument]
    {
        return map(lambda(file: file, line: line, column: column, fn))
    }

    func reduce<A, R>(
        _ initial: Rep<R>,
        _ combiner: Rep<(R, A) -> R>
        ) -> Rep<R> where Result == [A] {
        return ReduceExpression(initial: initial, combiner: combiner,
                                array: self)
    }

    func reduce<A, R>(
        file: StaticString = #file, line: UInt = #line, column: UInt = #column,
        _ initial: Rep<R>,
        _ combiner: @escaping (Rep<R>, Rep<A>) -> Rep<R>
        ) -> Rep<R> where Result == [A] {
        return reduce(initial,
                      lambda(file: file, line: line, column: column, combiner))
    }

    /// - Todo: To be removed when conditional conformance is supported. That is,
    /// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
    func reduce<A, R : Stageable>(
        _ initial: R,
        _ combiner: Rep<(R, A) -> R>
        ) -> Rep<R> where Result == [A] {
        return reduce(^initial, combiner)
    }

    /// - Todo: To be removed when conditional conformance is supported. That is,
    /// when we can declare `extension Rep : ExpressibleByXXX when Result == XXX`
    func reduce<A, R : Stageable>(
        file: StaticString = #file, line: UInt = #line, column: UInt = #column,
        _ initial: R,
        _ combiner: @escaping (Rep<R>, Rep<A>) -> Rep<R>
        ) -> Rep<R> where Result == [A] {
        return reduce(
            file: file, line: line, column: column,
            ^initial, combiner
        )
    }
}
