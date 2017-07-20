//: ### Value internals

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
struct Closure<Argument, Return> {
    var formal: UInt
    var body: Expression<Return>
}

///: ### Evaluation environment

class Environment {
    /// Tracks global symbol count
    private static var count: UInt = 0
    /// Maps symbols onto values
    private var symbolTable: [UInt : Any] = [:]
    /// Tracks global closure instances via static source location
    private static var closureInstances: [SourceLocation : Any] = [:]
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

    static func closure<T, U>(at location: SourceLocation) -> Closure<T, U>? {
        return closureInstances[location].map { $0 as! Closure<T, U> }
    }

    static func registerClosure<T, U>(_ closure: Closure<T, U>,
                                      at location: SourceLocation) {
        closureInstances[location] = closure
    }

    func makeSymbol() -> UInt {
        defer { Environment.count += 1 }
        return Environment.count
    }
}

//: ### Expressions

public class Expression<Result> {
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

    init(operator: Operator, left: Expression<Operand>, right: Expression<Operand>) {
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

class LambdaExpression<Argument, Return> : Expression<(Argument) -> Return> {
    typealias MetaClosure = (Expression<Argument>) -> Expression<Return>
    var metaClosure: MetaClosure
    var location: SourceLocation

    init(closure: @escaping MetaClosure, location: SourceLocation) {
        self.metaClosure = closure
        self.location = location
    }

    override func evaluated(in env: Environment) -> (Argument) -> Return {
        let closure: Closure<Argument, Return> = Environment.closure(at: location)
            ?? {
            let sym = env.makeSymbol()
            let symExp = SymbolExpression<Argument>(value: sym)
            let body = metaClosure(symExp)
            let closure = Closure<Argument, Return>(formal: sym, body: body)
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
