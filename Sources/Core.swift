//
//  Core.swift
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

protocol Staged {
    associatedtype Result
    func evaluated(in env: Environment) -> Result
}

public class Expression<Result> : Staged {
    func evaluated(in env: Environment) -> Result {
        fatalError("Oh no!")
    }
}

class ConstantExpression<Result> : Expression<Result> {
    var value: Result

    init(value: Result) {
        self.value = value
    }

    override func evaluated(in env: Environment) -> Result {
        return value
    }
}

class SymbolExpression<Result> : Expression<Result> {
    var value: UInt

    init(value: UInt) {
        self.value = value
    }

    override func evaluated(in env: Environment) -> Result {
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

class BinaryExpression<Operator, Operand, Result> : Expression<Result> {
    typealias Combiner = (Operand, Operand) -> Result
    var `operator`: Operator
    var left: Expression<Operand>
    var right: Expression<Operand>

    init(operator: Operator, left: Expression<Operand>,
         right: Expression<Operand>) {
        self.`operator` = `operator`
        self.left = left
        self.right = right
    }
}

class ArithmeticExpression<Operand : Numeric>
    : BinaryExpression<ArithmeticOperator, Operand, Operand> {
    override func evaluated(in env: Environment) -> Operand {
        let lhs = left.evaluated(in: env), rhs = right.evaluated(in: env)
        let op: Combiner
        switch `operator` {
        case .add: op = (+)
        case .subtract: op = (-)
        case .multiply: op = (*)
        }
        return op(lhs, rhs)
    }
}

class ComparisonExpression<Operand : Comparable>
    : BinaryExpression<ComparisonOperator, Operand, Bool> {
    override func evaluated(in env: Environment) -> Bool {
        let lhs = left.evaluated(in: env), rhs = right.evaluated(in: env)
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
    override func evaluated(in env: Environment) -> Bool {
        let lhs = left.evaluated(in: env), rhs = right.evaluated(in: env)
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

    override func evaluated(in env: Environment) -> Operand {
        return -operand.evaluated(in: env)
    }
}

class LogicalNotExpression : Expression<Bool> {
    var operand: Expression<Bool>

    init(operand: Expression<Bool>) {
        self.operand = operand
    }

    override func evaluated(in env: Environment) -> Bool {
        return !operand.evaluated(in: env)
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

    override func evaluated(in env: Environment) -> (Argument) -> Return {
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
            return closure.body.evaluated(in: newEnv)
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

    override func evaluated(in env: Environment) -> Return {
        let argVal = argument.evaluated(in: env)
        let cloVal = closure.evaluated(in: env)
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

    override func evaluated(in env: Environment) -> Result {
        let condVal = condition.evaluated(in: env)
        return condVal ? then().evaluated(in: env) : `else`().evaluated(in: env)
    }
}

class CondExpression<Result> : Expression<Result> {
    typealias Clause = (Expression<Bool>, () -> Expression<Result>)
    var clauses: [Clause]
    var `else`: () -> Expression<Result>

    init(clauses: [Clause], `else`: @autoclosure @escaping () -> Expression<Result>) {
        self.clauses = clauses
        self.`else` = `else`
    }

    override func evaluated(in env: Environment) -> Result {
        for (cond, then) in clauses where cond.evaluated(in: env) {
            return then().evaluated(in: env)
        }
        return `else`().evaluated(in: env)
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

    override func evaluated(in env: Environment) -> [MapResult] {
        let cloVal = functor.evaluated(in: env)
        let arrVal = array.evaluated(in: env)
        return arrVal.map { cloVal($0) }
    }
}

class ReduceExpression<Argument, Result> : Expression<Result> {
    typealias Combiner = Expression<((Result, Argument)) -> Result>
    var combiner: Combiner
    var initial: Expression<Result>
    var array: Expression<[Argument]>

    init(initial: Expression<Result>, combiner: Combiner,
         array: Expression<[Argument]>) {
        self.initial = initial
        self.combiner = combiner
        self.array = array
    }

    override func evaluated(in env: Environment) -> Result {
        // TODO: refactor after multiple args are supported
        let cloVal = combiner.evaluated(in: env)
        var accVal = initial.evaluated(in: env)
        let arrVal = array.evaluated(in: env)
        for v in arrVal {
            accVal = cloVal((accVal, v))
        }
        return accVal
    }
}
