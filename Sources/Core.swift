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
    final var cachedResult: Result? = nil
    final var shouldInvalidateCache: Bool

    init(shouldInvalidateCache: Bool) {
        self.shouldInvalidateCache = shouldInvalidateCache
    }

    fileprivate func containsSymbol(otherThan sym: UInt) -> Bool {
        fatalError("Override me")
    }

    fileprivate func evaluated(in env: Environment) -> Result {
        fatalError("Override me")
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

    init(value: Result) {
        self.value = value
        super.init(shouldInvalidateCache: false)
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

    init(value: UInt) {
        self.value = value
        super.init(shouldInvalidateCache: true)
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

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return left.containsSymbol(otherThan: sym)
            || right.containsSymbol(otherThan: sym)
    }

    init(operator: Operator, left: Expression<Operand>,
         right: Expression<Operand>) {
        self.`operator` = `operator`
        self.left = left
        self.right = right
        super.init(shouldInvalidateCache:
            left.shouldInvalidateCache || right.shouldInvalidateCache)
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

    init(operand: Expression<Operand>) {
        self.operand = operand
        super.init(shouldInvalidateCache: operand.shouldInvalidateCache)
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

    init(operand: Expression<Bool>) {
        self.operand = operand
        super.init(shouldInvalidateCache: operand.shouldInvalidateCache)
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return operand.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Bool {
        return !operand.result(in: env)
    }
}

final class LambdaExpression<Argument, Return> : Expression<(Argument) -> Return> {
    typealias MetaClosure = (Expression<Argument>) -> Expression<Return>
    let metaClosure: MetaClosure
    let location: SourceLocation

    init(closure: @escaping MetaClosure, location: SourceLocation) {
        self.metaClosure = closure
        self.location = location
        /// Assume not invalidating until proven (during one-time staging)
        /// otherwise
        super.init(shouldInvalidateCache: false)
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return false
    }

    fileprivate override func evaluated(in env: Environment) -> (Argument) -> Return {
        let closure: Closure<Return> =
            Environment.closure(at: location) ?? {
                let sym = Environment.makeSymbol()
                let symExp = SymbolExpression<Argument>(value: sym)
                let body = metaClosure(symExp)
                /// DFS in body and see if there's any SymbolExp whose
                /// ID does not equal `sym`. If any, set `shouldInvalidateCache`
                /// to `true`
                if body.containsSymbol(otherThan: sym) {
                    shouldInvalidateCache = true
                }
                let closure = Closure(formal: sym, body: body)
                Environment.registerClosure(closure, at: location)
                return closure
            }()
        return { arg in
            let newEnv = Environment(parent: env)
            newEnv.insert(arg, for: closure.formal)
            return closure.body.result(in: newEnv)
        }
    }
}

final class ApplyExpression<Argument, Return> : Expression<Return> {
    typealias Closure = Expression<(Argument) -> Return>
    let closure: Closure
    let argument: Expression<Argument>

    init(closure: Closure, argument: Expression<Argument>) {
        self.closure = closure
        self.argument = argument
        super.init(shouldInvalidateCache:
            closure.shouldInvalidateCache || argument.shouldInvalidateCache)
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
    private let makeThen: () -> Expression<Result>
    private let makeElse: () -> Expression<Result>
    lazy var then: Expression<Result> = self.makeThen()
    lazy var `else`: Expression<Result> = self.makeElse()

    init(condition: Expression<Bool>,
         then: @autoclosure @escaping () -> Expression<Result>,
         else: @autoclosure @escaping () -> Expression<Result>) {
        self.condition = condition
        self.makeThen = then
        self.makeElse = `else`
        super.init(shouldInvalidateCache: condition.shouldInvalidateCache)
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
    enum ThenClause {
        case uninitialized(() -> Expression<Result>)
        case initialized(Expression<Result>)

        var initialized: Expression<Result> {
            mutating get {
                switch self {
                case let .initialized(exp):
                    return exp
                case let .uninitialized(makeExp):
                    let exp = makeExp()
                    self = .initialized(exp)
                    return exp
                }
            }
        }
    }
    typealias Clause = (Expression<Bool>, ThenClause)
    var clauses: [Clause]
    private let makeElse: () -> Expression<Result>
    lazy var `else`: Expression<Result> = self.makeElse()

    init(clauses: [(Expression<Bool>, () -> Expression<Result>)],
         `else`: @autoclosure @escaping () -> Expression<Result>) {
        self.clauses = clauses.map { ($0, .uninitialized($1)) }
        self.makeElse = `else`
        var shouldInvalidateCache: Bool = false
        for (exp, _) in clauses where exp.shouldInvalidateCache {
            shouldInvalidateCache = true
        }
        super.init(shouldInvalidateCache: shouldInvalidateCache)
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        for (exp, _) in clauses where exp.containsSymbol(otherThan: sym) {
            return true
        }
        return false
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        for (i, (cond, _)) in clauses.enumerated() where cond.result(in: env) {
            return clauses[i].1.initialized.result(in: env)
        }
        return `else`.result(in: env)
    }
}

final class MapExpression<Argument, MapResult> : Expression<[MapResult]> {
    typealias Functor = Expression<(Argument) -> MapResult>
    let functor: Functor
    let array: Expression<[Argument]>

    init(functor: Functor, array: Expression<[Argument]>) {
        self.functor = functor
        self.array = array
        super.init(shouldInvalidateCache:
            functor.shouldInvalidateCache || array.shouldInvalidateCache)
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

    init(initial: Expression<Result>, combiner: Combiner,
         array: Expression<[Argument]>) {
        self.initial = initial
        self.combiner = combiner
        self.array = array
        super.init(shouldInvalidateCache: combiner.shouldInvalidateCache
                                       || initial.shouldInvalidateCache
                                       || array.shouldInvalidateCache)
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return combiner.containsSymbol(otherThan: sym)
            || initial.containsSymbol(otherThan: sym)
            || array.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Result {
        let cloVal = combiner.result(in: env)
        var accVal = initial.result(in: env)
        let arrVal = array.result(in: env)
        for v in arrVal {
            accVal = cloVal(accVal, v)
        }
        return accVal
    }
}

final class TupleExpression<First, Second> : Expression<(First, Second)> {
    let first: Expression<First>
    let second: Expression<Second>

    init(_ first: Expression<First>, _ second: Expression<Second>) {
        self.first = first
        self.second = second
        super.init(shouldInvalidateCache:
            first.shouldInvalidateCache || second.shouldInvalidateCache)
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

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
        super.init(shouldInvalidateCache: tuple.shouldInvalidateCache)
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

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
        super.init(shouldInvalidateCache: tuple.shouldInvalidateCache)
    }

    override func containsSymbol(otherThan sym: UInt) -> Bool {
        return tuple.containsSymbol(otherThan: sym)
    }

    fileprivate override func evaluated(in env: Environment) -> Second {
        return tuple.result(in: env).1
    }
}
