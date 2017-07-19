//: # Lightweight Modular Staging in Swift
//: ## Base types

class Environment {
    typealias SymbolTable = [Int : Any]
    private var count: Int = 0
    private var stack: [SymbolTable] = [[:]]

    func enterScope() {
        stack.append([:])
    }

    func exitScope() {
        stack.removeLast()
    }

    func value<T>(for symbol: Int) -> T? {
        return stack.lazy.reversed().flatMap { $0[symbol] as? T }.first
    }

    func insert<T>(_ value: T, for symbol: Int) {
        stack[stack.endIndex][symbol] = value
    }

    func makeSymbol() -> Int {
        defer { count += 1 }
        return count
    }
}

protocol Staged : class {
    associatedtype Result
    func evaluated(in env: Environment) -> Result
}

class Expression<Result> : Staged {
    func evaluated(in env: Environment) -> Result {
        fatalError("Oh no!")
    }
}

struct Rep<T> {
    var expression: Expression<T>
}

//: ## Atomic Expressions

class ConstantExpression<T> : Expression<T> {
    typealias Result = T
    var value: T
    
    init(value: T) {
        self.value = value
    }

    override func evaluated(in env: Environment) -> T {
        return value
    }
}

class SymbolExpression<T> : Expression<T> {
    typealias Result = T
    var value: Int
    
    init(value: Int) {
        self.value = value
    }

    override func evaluated(in env: Environment) -> T {
        guard let val: T = env.value(for: value) else {
            fatalError("Unbound symbol \(value)")
        }
        return val
    }
}

//: ## Composite Expressions

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
    typealias LazyCombiner = (Operand, @autoclosure () throws -> Operand) throws -> Result

    var `operator`: Operator
    var left: Expression<Operand>
    var right: Expression<Operand>

    init(operator: Operator, left: Expression<Operand>, right: Expression<Operand>) {
        self.`operator` = `operator`
        self.left = left
        self.right = right
    }
}

class ArithmeticExpression<Operand : Numeric>
    : BinaryExpression<ArithmeticOperator, Operand, Operand> {
    override func evaluated(in env: Environment) -> Result {
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
        let op: LazyCombiner
        switch `operator` {
        case .and: op = (&&)
        case .or: op = (||)
        }
        return try! op(lhs, rhs)
    }
}

class LambdaExpression<Argument, Return> : Expression<(Argument) -> Return> {
    typealias Closure = (Expression<Argument>) -> Expression<Return>
    var closure: Closure

    init(closure: @escaping Closure) {
        self.closure = closure
    }

    override func evaluated(in env: Environment) -> (Argument) -> Return {
        let sym = env.makeSymbol()
        let symExp = SymbolExpression<Argument>(value: sym)
        let body = closure(symExp)
        return { arg in
            env.enterScope()
            env.insert(arg, for: sym)
            defer { env.exitScope() }
            return body.evaluated(in: env)
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
