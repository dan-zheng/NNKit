//: # Lightweight Modular Staging in Swift
//: ## Base types

class Environment {
    typealias SymbolTable = [Int : Any]
    private static var count: Int = 0
    private var symbolTable: SymbolTable = [:]
    weak var parent: Environment?

    init(parent: Environment?) {
        self.parent = parent
    }

    func value<T>(for symbol: Int) -> T? {
        return symbolTable[symbol].map { $0 as! T }
            ?? parent?.value(for: symbol)
    }

    func insert<T>(_ value: T, for symbol: Int) {
        symbolTable[symbol] = value
    }

    func makeSymbol() -> Int {
        defer { Environment.count += 1 }
        return Environment.count
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

struct Rep<Result> {
    var expression: Expression<Result>

    init(_ expression: Expression<Result>) {
        self.expression = expression
    }
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
        switch `operator` {
        case .and: return lhs && rhs
        case .or: return lhs || rhs
        }
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
            let newEnv = Environment(parent: env)
            newEnv.insert(arg, for: sym)
            return body.evaluated(in: newEnv)
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
    var then: Expression<Result>
    var `else`: Expression<Result>

    init(condition: Expression<Bool>,
         then: Expression<Result>, else: Expression<Result>) {
        self.condition = condition
        self.then = then
        self.`else` = `else`
    }

    override func evaluated(in env: Environment) -> Result {
        let condVal = condition.evaluated(in: env)
        return condVal ? then.evaluated(in: env) : `else`.evaluated(in: env)
    }
}

//: ## DSL

extension Rep {
    func evaluated() -> Result {
        return expression.evaluated(in: Environment(parent: nil))
    }
}

func int(_ value: Int) -> Rep<Int> {
    return Rep(ConstantExpression(value: value))
}

func float(_ value: Float) -> Rep<Float> {
    return Rep(ConstantExpression(value: value))
}

func bool(_ value: Bool) -> Rep<Bool> {
    return Rep(ConstantExpression(value: value))
}

extension Rep where Result : Numeric {
    static func + (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(ArithmeticExpression(operator: .add,
                                        left: lhs.expression,
                                        right: rhs.expression))
    }

    static func - (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(ArithmeticExpression(operator: .subtract,
                                        left: lhs.expression,
                                        right: rhs.expression))
    }

    static func * (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(ArithmeticExpression(operator: .multiply,
                                        left: lhs.expression,
                                        right: rhs.expression))
    }
}

extension Rep where Result : Comparable {
    static func > (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .greaterThan,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }

    static func >= (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .greaterThanOrEqual,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }

    static func < (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .lessThan,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }

    static func <= (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .lessThanOrEqual,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }

    static func == (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .equal,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }

    static func != (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(ComparisonExpression(operator: .notEqual,
                                              left: lhs.expression,
                                              right: rhs.expression))
    }
}

extension Rep where Result == Bool {
    static func && (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(BooleanExpression(operator: .and,
                                     left: lhs.expression,
                                     right: rhs.expression))
    }

    static func || (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(BooleanExpression(operator: .or,
                                     left: lhs.expression,
                                     right: rhs.expression))
    }
}

func lambda<Argument, Result>(_ closure: @escaping (Rep<Argument>) -> Rep<Result>)
    -> Rep<(Argument) -> Result> {
    return Rep(LambdaExpression { closure(Rep($0)).expression })
}

extension Rep {
    subscript<Argument, ClosureResult>(_ arg: Rep<Argument>) -> Rep<ClosureResult>
        where Result == (Argument) -> ClosureResult {
        return Rep<ClosureResult>(
            ApplyExpression<Argument, ClosureResult>(closure: expression,
                                                     argument: arg.expression))
    }
}

func `if`<Result>(_ condition: Rep<Bool>, then: Rep<Result>, else: Rep<Result>) -> Rep<Result> {
    return Rep(IfExpression(condition: condition.expression,
                            then: then.expression, else: `else`.expression))
}

let x = float(10)
let y = float(20)
(x + y).evaluated()

let addTen = lambda { x in
    x + float(10)
}
addTen.evaluated()(10)

let round = lambda { x in
    `if`(x >= float(0.5), then: float(1), else: float(0))
}
round[float(0.3)].evaluated()
round[float(0.73)].evaluated()

let curriedAdd: Rep<(Float) -> (Float) -> Float> =
    lambda { x in lambda { y in x + y } }
curriedAdd[x][y].evaluated()
