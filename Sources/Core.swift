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

    /// Subclasses should decide whether should cache should be invalidated
    var shouldInvalidateCache: Bool {
        fatalError("Oh no!")
    }

    /// One-time initialized property
    private final lazy var _shouldInvalidateCache: Bool =
        self.shouldInvalidateCache

    fileprivate func evaluated(in env: Environment) -> Result {
        fatalError("Oh no!")
    }

    private final func cache(_ result: Result) -> Result {
        cachedResult = result
        return result
    }

    final func result(in env: Environment) -> Result {
        if _shouldInvalidateCache {
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

class ConstantExpression<Result> : Expression<Result> {
    var value: Result

    init(value: Result) {
        self.value = value
    }

    override var shouldInvalidateCache: Bool {
        return false
    }

    override fileprivate func evaluated(in env: Environment) -> Result {
        return value
    }
}

class SymbolExpression<Result> : Expression<Result> {
    var value: UInt

    init(value: UInt) {
        self.value = value
    }

    override var shouldInvalidateCache: Bool {
        return true
    }

    override fileprivate func evaluated(in env: Environment) -> Result {
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
    var `operator`: Operator
    var left: Expression<Operand>
    var right: Expression<Operand>

    override var shouldInvalidateCache: Bool {
        return left.shouldInvalidateCache || right.shouldInvalidateCache
    }

    init(operator: Operator, left: Expression<Operand>,
         right: Expression<Operand>) {
        self.`operator` = `operator`
        self.left = left
        self.right = right
    }
}

class ArithmeticExpression<Operand : Numeric>
    : BinaryExpression<ArithmeticOperator, Operand, Operand> {
    override fileprivate func evaluated(in env: Environment) -> Operand {
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

class IntegerDivisionExpresison<Operand : BinaryInteger>
    : BinaryExpression<DivisionOperator, Operand, Operand> {
    override fileprivate func evaluated(in env: Environment) -> Operand {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        let op: Combiner
        switch `operator` {
        case .divide: op = (/)
        case .remainder: op = (%)
        }
        return op(lhs, rhs)
    }
}

class FloatingPointDivisionExpression<Operand : FloatingPoint>
    : BinaryExpression<DivisionOperator, Operand, Operand> {
    override fileprivate func evaluated(in env: Environment) -> Operand {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        switch `operator` {
        case .divide: return lhs / rhs
        case .remainder: return lhs.truncatingRemainder(dividingBy: rhs)
        }
    }
}

class ComparisonExpression<Operand : Comparable>
    : BinaryExpression<ComparisonOperator, Operand, Bool> {
    override fileprivate func evaluated(in env: Environment) -> Bool {
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

class BooleanExpression : BinaryExpression<BooleanOperator, Bool, Bool> {
    override fileprivate func evaluated(in env: Environment) -> Bool {
        let lhs = left.result(in: env), rhs = right.result(in: env)
        switch `operator` {
        case .and: return lhs && rhs
        case .or: return lhs || rhs
        }
    }
}

class NegateExpression<Operand : SignedNumeric> : Expression<Operand> {
    var operand: Expression<Operand>

    init(operand: Expression<Operand>) {
        self.operand = operand
    }

    override var shouldInvalidateCache: Bool {
        return operand.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Operand {
        return -operand.result(in: env)
    }
}

class LogicalNotExpression : Expression<Bool> {
    var operand: Expression<Bool>

    init(operand: Expression<Bool>) {
        self.operand = operand
    }

    override var shouldInvalidateCache: Bool {
        return operand.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Bool {
        return !operand.result(in: env)
    }
}

class LambdaExpression<Argument, Return> : Expression<(Argument) -> Return> {
    typealias MetaClosure = (Expression<Argument>) -> Expression<Return>
    var metaClosure: MetaClosure
    var location: SourceLocation

    init(closure: @escaping MetaClosure, location: SourceLocation) {
        self.metaClosure = closure
        self.location = location
    }

    override var shouldInvalidateCache: Bool {
        return false
    }

    override fileprivate func evaluated(in env: Environment) -> (Argument) -> Return {
        let closure: Closure<Return> =
            Environment.closure(at: location) ?? {
                let sym = Environment.makeSymbol()
                let symExp = SymbolExpression<Argument>(value: sym)
                let body = metaClosure(symExp)
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

class ApplyExpression<Argument, Return> : Expression<Return> {
    typealias Closure = Expression<(Argument) -> Return>
    var closure: Closure
    var argument: Expression<Argument>

    init(closure: Closure, argument: Expression<Argument>) {
        self.closure = closure
        self.argument = argument
    }

    override var shouldInvalidateCache: Bool {
        return argument.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Return {
        let argVal = argument.result(in: env)
        let cloVal = closure.result(in: env)
        return cloVal(argVal)
    }
}

class IfExpression<Result> : Expression<Result> {
    var condition: Expression<Bool>
    var then: () -> Expression<Result>
    var `else`: () -> Expression<Result>

    init(condition: Expression<Bool>,
         then: @autoclosure @escaping () -> Expression<Result>,
         else: @autoclosure @escaping () -> Expression<Result>) {
        self.condition = condition
        self.then = then
        self.`else` = `else`
    }

    override var shouldInvalidateCache: Bool {
        return condition.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Result {
        return condition.result(in: env)
            ? then().result(in: env)
            : `else`().result(in: env)
    }
}

class CondExpression<Result> : Expression<Result> {
    typealias Clause = (Expression<Bool>, () -> Expression<Result>)
    var clauses: [Clause]
    var `else`: () -> Expression<Result>

    init(clauses: [Clause],
         `else`: @autoclosure @escaping () -> Expression<Result>) {
        self.clauses = clauses
        self.`else` = `else`
    }

    override var shouldInvalidateCache: Bool {
        for (exp, _) in clauses where exp.shouldInvalidateCache {
            return true
        }
        return false
    }

    override fileprivate func evaluated(in env: Environment) -> Result {
        for (cond, then) in clauses where cond.result(in: env) {
            return then().result(in: env)
        }
        return `else`().result(in: env)
    }
}

class MapExpression<Argument, MapResult> : Expression<[MapResult]> {
    typealias Functor = Expression<(Argument) -> MapResult>
    var functor: Functor
    var array: Expression<[Argument]>

    init(functor: Functor, array: Expression<[Argument]>) {
        self.functor = functor
        self.array = array
    }

    override var shouldInvalidateCache: Bool {
        return functor.shouldInvalidateCache || array.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> [MapResult] {
        let cloVal = functor.result(in: env)
        let arrVal = array.result(in: env)
        return arrVal.map { cloVal($0) }
    }
}

class ReduceExpression<Argument, Result> : Expression<Result> {
    typealias Combiner = Expression<(Result, Argument) -> Result>
    var combiner: Combiner
    var initial: Expression<Result>
    var array: Expression<[Argument]>

    init(initial: Expression<Result>, combiner: Combiner,
         array: Expression<[Argument]>) {
        self.initial = initial
        self.combiner = combiner
        self.array = array
    }

    override var shouldInvalidateCache: Bool {
        return combiner.shouldInvalidateCache
            || initial.shouldInvalidateCache
            || array.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Result {
        // TODO: refactor after multiple args are supported
        let cloVal = combiner.result(in: env)
        var accVal = initial.result(in: env)
        let arrVal = array.result(in: env)
        for v in arrVal {
            accVal = cloVal(accVal, v)
        }
        return accVal
    }
}

class TupleExpression<First, Second> : Expression<(First, Second)> {
    let first: Expression<First>
    let second: Expression<Second>

    init(_ first: Expression<First>, _ second: Expression<Second>) {
        self.first = first
        self.second = second
    }

    override var shouldInvalidateCache: Bool {
        return first.shouldInvalidateCache || second.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> (First, Second) {
        return (first.result(in: env), second.result(in: env))
    }
}

class TupleExtractFirstExpression<First, Second> : Expression<First> {
    let tuple: Expression<(First, Second)>

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
    }

    override var shouldInvalidateCache: Bool {
        return tuple.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> First {
        return tuple.result(in: env).0
    }
}

class TupleExtractSecondExpression<First, Second> : Expression<Second> {
    let tuple: Expression<(First, Second)>

    init(_ tuple: Expression<(First, Second)>) {
        self.tuple = tuple
    }

    override var shouldInvalidateCache: Bool {
        return tuple.shouldInvalidateCache
    }

    override fileprivate func evaluated(in env: Environment) -> Second {
        return tuple.result(in: env).1
    }
}
