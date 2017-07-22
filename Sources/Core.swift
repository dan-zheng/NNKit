//
//  Core.swift
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

protocol Staged {
    associatedtype Result
    func result(in env: Environment) -> Result
}

public class Expression<Result> : Staged {
    private final var cachedResult: Result? = nil

    /// Conservative assumption, to be overriden
    lazy var shouldInvalidateCache: Bool = true

    fileprivate func containsSymbol(otherThan sym: UInt) -> Bool {
        fatalError("Override me")
    }

    fileprivate func evaluated(in env: Environment) -> Result {
        fatalError("Override me")
    }

    fileprivate func updateInvalidation<R>(from exp: Expression<R>) {
        shouldInvalidateCache =
            shouldInvalidateCache || exp.shouldInvalidateCache
    }

    final func result(in env: Environment) -> Result {
        if shouldInvalidateCache {
            cachedResult = nil
            return evaluated(in: env)
        }
        if let result = cachedResult {
            return result
        }
        let result = evaluated(in: env)
        cachedResult = result
        return result
    }
}

final class ConstantExpression<Result> : Expression<Result> {
    let value: Result
    override lazy var shouldInvalidateCache: Bool = false

    init(value: Result) {
        self.value = value
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return false
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        return value
    }
}

final class SymbolExpression<Result> : Expression<Result> {
    let value: UInt
    override lazy var shouldInvalidateCache: Bool = true

    init(value: UInt) {
        self.value = value
    }

    fileprivate override func containsSymbol(otherThan sym: UInt) -> Bool {
        return sym != value
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        guard let val: Result = env.value(for: value) else {
            fatalError("Unbound symbol \(value)")
        }
        return val
    }
}

enum ArithmeticOperator {
    case add, subtract, multiply
}

enum ComparisonOperator {
    case greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual
    case equal, notEqual
}

enum BooleanOperator {
    case and, or
}

enum DivisionOperator {
    case divide, remainder
}

class BinaryExpression<Operator, Operand, Result> : Expression<Result> {
    typealias Combiner = (Operand, Operand) -> Result
    let `operator`: Operator
    let left: Expression<Operand>
    let right: Expression<Operand>

    override lazy var shouldInvalidateCache: Bool =
        self.left.shouldInvalidateCache || self.right.shouldInvalidateCache

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return left.containsSymbol(otherThan: sym)
            || right.containsSymbol(otherThan: sym)
    }

    init(operator: Operator, left: Expression<Operand>,
         right: Expression<Operand>) {
        self.`operator` = `operator`
        self.left = left
        self.right = right
    }
}

final class ArithmeticExpression<Operand : Numeric>
    : BinaryExpression<ArithmeticOperator, Operand, Operand> {
    fileprivate override func evaluated(in env: Environment) -> Operand {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        let op: Combiner
        switch `operator` {
        case .add: op = (+)
        case .subtract: op = (-)
        case .multiply: op = (*)
        }
        return op(lhs, rhs)
    }
}

final class IntegerDivisionExpresison<Operand : BinaryInteger>
    : BinaryExpression<DivisionOperator, Operand, Operand> {
    fileprivate override func evaluated(in env: Environment) -> Operand {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        let op: Combiner
        switch `operator` {
        case .divide: op = (/)
        case .remainder: op = (%)
        }
        return op(lhs, rhs)
    }
}

final class FloatingPointDivisionExpression<Operand : FloatingPoint>
    : BinaryExpression<DivisionOperator, Operand, Operand> {
    fileprivate override func evaluated(in env: Environment) -> Operand {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        switch `operator` {
        case .divide: return lhs / rhs
        case .remainder: return lhs.truncatingRemainder(dividingBy: rhs)
        }
    }
}

final class ComparisonExpression<Operand : Comparable>
    : BinaryExpression<ComparisonOperator, Operand, Bool> {
    fileprivate override func evaluated(in env: Environment) -> Bool {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        let op: Combiner
        switch `operator` {
        case .equal: op = (==)
        case .greaterThan: op = (>)
        case .greaterThanOrEqual: op = (>=)
        case .lessThan: op = (<)
        case .lessThanOrEqual: op = (<=)
        case .notEqual: op = (!=)
        }
        return op(lhs, rhs)
    }
}

final class BooleanExpression : BinaryExpression<BooleanOperator, Bool, Bool> {
    fileprivate override func evaluated(in env: Environment) -> Bool {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        switch `operator` {
        case .and: return lhs && rhs
        case .or: return lhs || rhs
        }
    }
}

final class NegateExpression<Operand : SignedNumeric> : Expression<Operand> {
    let operand: Expression<Operand>

    override lazy var shouldInvalidateCache: Bool =
        self.operand.shouldInvalidateCache

    init(operand: Expression<Operand>) {
        self.operand = operand
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return operand.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Operand {
        return -operand.result(in: env)
    }
}

final class LogicalNotExpression : Expression<Bool> {
    let operand: Expression<Bool>

    override lazy var shouldInvalidateCache: Bool =
        self.operand.shouldInvalidateCache

    init(operand: Expression<Bool>) {
        self.operand = operand
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return operand.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Bool {
        return !operand.result(in: env)
    }
}

fileprivate extension Closure {
    var hasFreeVariables: Bool {
        return body.containsSymbol(otherThan: formal)
    }
}

final class LambdaExpression<Argument, Return> : Expression<(Argument) -> Return> {
    let metaClosure: (Expression<Argument>) -> Expression<Return>
    let location: SourceLocation

    override lazy var shouldInvalidateCache: Bool = true

    private var closure: Closure<Return> {
        if let closure: Closure<Return> = Environment.closure(at: self.location) {
            return closure
        }
        let sym = Environment.makeSymbol()
        let symExp = SymbolExpression<Argument>(value: sym)
        let body = self.metaClosure(symExp)
        /// DFS in body and see if there's any SymbolExp whose
        /// ID does not equal `sym`. If any, set `shouldInvalidateCache`
        /// to `true`
        let closure = Closure(formal: sym, body: body)
        self.shouldInvalidateCache = closure.hasFreeVariables
        Environment.registerClosure(closure, at: self.location)
        return closure
    }

    init(metaClosure: @escaping (Expression<Argument>) -> Expression<Return>,
         location: SourceLocation) {
        self.metaClosure = metaClosure
        self.location = location
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return false
    }

    fileprivate override func evaluated(in env: Environment) -> (Argument) -> Return {
        return { arg in
            let newEnv = Environment(parent: env)
            newEnv.insert(arg, for: self.closure.formal)
            return self.closure.body.result(in: newEnv)
        }
    }
}

final class ApplyExpression<Argument, Return> : Expression<Return> {
    let closure: Expression<(Argument) -> Return>
    let argument: Expression<Argument>

    override lazy var shouldInvalidateCache: Bool =
        self.closure.shouldInvalidateCache
     || self.argument.shouldInvalidateCache

    init(closure: Expression<(Argument) -> Return>,
         argument: Expression<Argument>) {
        self.closure = closure
        self.argument = argument
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return closure.containsSymbol(otherThan: sym)
            || argument.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Return {
        let argVal = argument.result(in: env)
        let cloVal = closure.result(in: env)
        return cloVal(argVal)
    }
}

final class IfExpression<Result> : Expression<Result> {
    let condition: Expression<Bool>
    let then: Expression<Result>
    let `else`: Expression<Result>

    override lazy var shouldInvalidateCache: Bool =
        self.condition.shouldInvalidateCache
     || self.then.shouldInvalidateCache
     || self.`else`.shouldInvalidateCache

    init(condition: Expression<Bool>, then: Expression<Result>,
         else: Expression<Result>) {
        self.condition = condition
        self.then = then
        self.`else` = `else`
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return condition.containsSymbol(otherThan: sym)
            || then.containsSymbol(otherThan: sym)
            || `else`.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        return condition.result(in: env)
            ? then.result(in: env)
            : `else`.result(in: env)
    }
}

final class CondExpression<Result> : Expression<Result> {
    typealias Clause = (Expression<Bool>, Expression<Result>)
    let clauses: [Clause]
    let `else`: Expression<Result>

    override lazy var shouldInvalidateCache: Bool = {
        for (cond, then) in self.clauses {
            if cond.shouldInvalidateCache || then.shouldInvalidateCache {
                return true
            }
        }
        return self.`else`.shouldInvalidateCache
    }()

    init(clauses: [(Expression<Bool>, Expression<Result>)],
         `else`: Expression<Result>) {
        self.clauses = clauses
        self.`else` = `else`
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        for (exp, then) in clauses {
            if exp.containsSymbol(otherThan: sym) ||
                then.containsSymbol(otherThan: sym) {
                return true
            }
        }
        return `else`.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        for (cond, then) in clauses where cond.result(in: env) {
            return then.result(in: env)
        }
        return `else`.result(in: env)
    }
}

final class MapExpression<Argument, MapResult> : Expression<[MapResult]> {
    typealias Functor = Expression<(Argument) -> MapResult>
    let functor: Functor
    let array: Expression<[Argument]>

    override lazy var shouldInvalidateCache: Bool =
        self.functor.shouldInvalidateCache || self.array.shouldInvalidateCache

    init(functor: Functor, array: Expression<[Argument]>) {
        self.functor = functor
        self.array = array
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return functor.containsSymbol(otherThan: sym)
            || array.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> [MapResult] {
        let cloVal = functor.result(in: env)
        let arrVal = array.result(in: env)
        return arrVal.map { cloVal($0) }
    }
}

final class ReduceExpression<Argument, Result> : Expression<Result> {
    typealias Combiner = Expression<(Result, Argument) -> Result>
    let combiner: Combiner
    let initial: Expression<Result>
    let array: Expression<[Argument]>

    override lazy var shouldInvalidateCache: Bool =
        self.combiner.shouldInvalidateCache
     || self.initial.shouldInvalidateCache
     || self.array.shouldInvalidateCache

    init(initial: Expression<Result>, combiner: Combiner,
         array: Expression<[Argument]>) {
        self.initial = initial
        self.combiner = combiner
        self.array = array
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return combiner.containsSymbol(otherThan: sym)
            || initial.containsSymbol(otherThan: sym)
            || array.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        let cloVal = combiner.result(in: env)
        let accVal = initial.result(in: env)
        let arrVal = array.result(in: env)
        return arrVal.reduce(accVal, cloVal)
    }
}

final class FilterExpression<Element> : Expression<[Element]> {
    typealias Filter = Expression<(Element) -> Bool>
    let filter: Filter
    let array: Expression<[Element]>

    override lazy var shouldInvalidateCache: Bool =
        self.filter.shouldInvalidateCache || self.array.shouldInvalidateCache

    init(filter: Filter, array: Expression<[Element]>) {
        self.filter = filter
        self.array = array
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return filter.containsSymbol(otherThan: sym)
            || array.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> [Element] {
        let cloVal = filter.result(in: env)
        let arrVal = array.result(in: env)
        return arrVal.filter { cloVal($0) }
    }
}

final class ZipExpression<First, Second>
    : Expression<Zip2Sequence<[First], [Second]>> {
    let array1: Expression<[First]>
    let array2: Expression<[Second]>

    override lazy var shouldInvalidateCache: Bool =
        self.array1.shouldInvalidateCache || self.array2.shouldInvalidateCache

    init(array1: Expression<[First]>, array2: Expression<[Second]>) {
        self.array1 = array1
        self.array2 = array2
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return array1.containsSymbol(otherThan: sym)
            || array2.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment)
        -> Zip2Sequence<[First], [Second]> {
        return zip(array1.result(in: env), array2.result(in: env))
    }
}


final class ZipWithExpression<First, Second, ZipWithResult>
    : Expression<[ZipWithResult]> {
    typealias Combiner = Expression<(First, Second) -> ZipWithResult>
    let combiner: Combiner
    let array1: Expression<[First]>
    let array2: Expression<[Second]>

    override lazy var shouldInvalidateCache: Bool =
        self.combiner.shouldInvalidateCache
     || self.array1.shouldInvalidateCache
     || self.array2.shouldInvalidateCache

    init(combiner: Combiner, array1: Expression<[First]>,
         array2: Expression<[Second]>) {
        self.combiner = combiner
        self.array1 = array1
        self.array2 = array2
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return combiner.containsSymbol(otherThan: sym)
            || array1.containsSymbol(otherThan: sym)
            || array2.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> [ZipWithResult] {
        let cloVal = combiner.result(in: env)
        return zip(array1.result(in: env), array2.result(in: env))
            .map { cloVal($0.0, $0.1) }
    }
}

final class TupleExpression<First, Second> : Expression<(First, Second)> {
    let first: Expression<First>
    let second: Expression<Second>

    override lazy var shouldInvalidateCache: Bool =
        self.first.shouldInvalidateCache || self.second.shouldInvalidateCache

    init(_ first: Expression<First>, _ second: Expression<Second>) {
        self.first = first
        self.second = second
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return first.containsSymbol(otherThan: sym)
            || second.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> (First, Second) {
        return (first.result(in: env), second.result(in: env))
    }
}

final class TupleExtractFirstExpression<First, Second> : Expression<First> {
    let tuple: Expression<(First, Second)>

    override lazy var shouldInvalidateCache: Bool =
        self.tuple.shouldInvalidateCache

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return tuple.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> First {
        return tuple.result(in: env).0
    }
}

final class TupleExtractSecondExpression<First, Second> : Expression<Second> {
    let tuple: Expression<(First, Second)>

    override lazy var shouldInvalidateCache: Bool =
        self.tuple.shouldInvalidateCache

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return tuple.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Second {
        return tuple.result(in: env).1
    }
}
