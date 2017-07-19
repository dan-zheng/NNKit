protocol Primitive {}

extension Bool : Primitive {}
extension Int : Primitive {}
extension Float : Primitive {}
extension String : Primitive {}

enum ArithmeticOperator {
    case add, subtract, multiply, divide, modulo
}

enum ComparisonOperator {
    case greaterThan, lessThan, greaterThanOrEqual, lessThanOrEqual
    case equal, notEqual
}

enum BooleanOperator {
    case and, or
}

indirect enum Expression {
    case bool(Bool)
    case int(Int)
    case float(Float)
    case array([Primitive])
    case symbol(AnyHashable)
    case arithmetic(ArithmeticOperator, Expression, Expression)
    case compare(ComparisonOperator, Expression, Expression)
    case boolean(BooleanOperator, Expression, Expression)
    case not(Expression)
    case `if`(Expression, Expression, Expression)
    case map(Expression, Expression)
    case reduce(Expression, Expression, Expression)
    case lambda([AnyHashable], Expression)
    case apply(Expression, [Expression])
    case lambda2((Expression) -> Expression)
}

enum EvaluationError : Error {
    case undefinedSymbol(AnyHashable)
    case typeMismatch
    case typeError
}

extension Expression {
    func evaluated(in env: [AnyHashable : Any]) throws -> Any {
        switch self {
        case let .bool(b):
            return b
        case let .int(i):
            return i
        case let .float(f):
            return f
        case let .symbol(s):
            guard let val = env[s] else {
                throw EvaluationError.undefinedSymbol(s)
            }
            return val
        case let .arithmetic(op, lhs, rhs):
            switch (op, try lhs.evaluated(in: env), try rhs.evaluated(in: env)) {
            case let (.add, l as Float, r as Float):
                return l + r
            case let (.add, l as Int, r as Int):
                return l + r
            case let (.subtract, l as Float, r as Float):
                return l - r
            case let (.subtract, l as Int, r as Int):
                return l - r
            case let (.multiply, l as Float, r as Float):
                return l * r
            case let (.multiply, l as Int, r as Int):
                return l * r
            case let (.divide, l as Float, r as Float):
                return l / r
            case let (.divide, l as Int, r as Int):
                return l / r
            case let (.modulo, l as Int, r as Int):
                return l % r
            default:
                throw EvaluationError.typeMismatch
            }
        case let .compare(op, lhs, rhs):
            switch (op, try lhs.evaluated(in: env), try rhs.evaluated(in: env)) {
            case let (.greaterThan, l as Float, r as Float):
                return l > r
            case let (.greaterThanOrEqual, l as Float, r as Float):
                return l >= r
            case let (.lessThan, l as Float, r as Float):
                return l < r
            case let (.lessThanOrEqual, l as Float, r as Float):
                return l <= r
            case let (.equal, l as Float, r as Float):
                return l == r
            case let (.notEqual, l as Float, r as Float):
                return l != r
            case let (.greaterThan, l as Int, r as Int):
                return l > r
            case let (.greaterThanOrEqual, l as Int, r as Int):
                return l >= r
            case let (.lessThan, l as Int, r as Int):
                return l < r
            case let (.lessThanOrEqual, l as Int, r as Int):
                return l <= r
            case let (.equal, l as Int, r as Int):
                return l == r
            case let (.notEqual, l as Int, r as Int):
                return l != r
            default:
                throw EvaluationError.typeMismatch
            }
        case let .boolean(op, lhs, rhs):
            switch (op, try lhs.evaluated(in: env), try rhs.evaluated(in: env)) {
            case let (.and, l as Bool, r as Bool):
                return l && r
            case let (.or, l as Bool, r as Bool):
                return l || r
            default:
                throw EvaluationError.typeMismatch
            }
        case let .not(v):
            guard let b = try v.evaluated(in: env) as? Bool else {
                throw EvaluationError.typeError
            }
            return !b
        case let .lambda(vals, body):
            return { [env] (args: [Any]) -> Any in
                var newEnv = env
                for (v, arg) in zip(vals, args) {
                    newEnv[v] = arg
                }
                return try! body.evaluated(in: newEnv)
            } as Any
        case let .apply(fexp, args):
            guard let f = try fexp.evaluated(in: env) as? ([Any]) -> Any else {
                throw EvaluationError.typeError
            }
            let evaluatedArgs = try args.map {
                try $0.evaluated(in: env)
            }
            return f(evaluatedArgs)
        case let .if(cond, then, `else`):
            guard let condVal = try cond.evaluated(in: env) as? Bool else {
                throw EvaluationError.typeError
            }
            return try (condVal ? then : `else`).evaluated(in: env)
            
        // MARK: new stuff
        
        case let .array(a):
            return a
        case let .map(fexp, sequence):
            guard let f = try fexp.evaluated(in: env) as? ([Any]) -> Any else {
                throw EvaluationError.typeError
            }
            guard let s = try sequence.evaluated(in: env) as? [Any] else {
                throw EvaluationError.typeError
            }
            return s.map { f([$0]) }
        case let .reduce(fexp, acc, sequence):
            guard let f = try fexp.evaluated(in: env) as? ([Any]) -> Any else {
                throw EvaluationError.typeError
            }
            let a = try acc.evaluated(in: env)
            guard let s = try sequence.evaluated(in: env) as? [Any] else {
                throw EvaluationError.typeError
            }
            return s.reduce(a, { f([$0, $1]) })
        case let .lambda2(f):
            return f
        }
    }
}

struct Rep<T> {
    let expression: Expression
    init(_ expression: Expression) {
        self.expression = expression
    }
}

extension Rep where T : Numeric {
    static func + (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.add, lhs.expression, rhs.expression))
    }
    
    static func - (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.subtract, lhs.expression, rhs.expression))
    }
    
    static func * (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.multiply, lhs.expression, rhs.expression))
    }
    
    static func == (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.equal, lhs.expression, rhs.expression))
    }
}

extension Rep where T : Comparable {
    static func != (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.notEqual, lhs.expression, rhs.expression))
    }
    
    static func < (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.lessThan, lhs.expression, rhs.expression))
    }
    
    static func <= (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.lessThanOrEqual, lhs.expression, rhs.expression))
    }
    
    static func > (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.greaterThan, lhs.expression, rhs.expression))
    }
    
    static func >= (lhs: Rep, rhs: Rep) -> Rep<Bool> {
        return Rep<Bool>(.compare(.greaterThanOrEqual, lhs.expression, rhs.expression))
    }
}

extension Rep where T : BinaryInteger {
    static func / (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.divide, lhs.expression, rhs.expression))
    }
    
    static func % (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.modulo, lhs.expression, rhs.expression))
    }
}

extension Rep where T : FloatingPoint {
    static func / (lhs: Rep, rhs: Rep) -> Rep {
        return Rep(.arithmetic(.divide, lhs.expression, rhs.expression))
    }
}

func lambda<T>(in body: Rep<T>) -> Rep<() -> T> {
    return Rep(.lambda([], body.expression))
}

func lambda<T, U>(_ arg: AnyHashable, in body: Rep<U>) -> Rep<(T) -> U> {
    return Rep(.lambda([arg], body.expression))
}

func lambda<T, U, V>(_ args: (AnyHashable, AnyHashable),
                     in body: Rep<U>) -> Rep<(T, U) -> V> {
    return Rep(.lambda([args.0, args.1], body.expression))
}

func lambda<T, U, V, W>(_ args: (AnyHashable, AnyHashable, AnyHashable),
                        in body: Rep<U>) -> Rep<(T, U, V) -> W> {
    return Rep(.lambda([args.0, args.1, args.2], body.expression))
}

extension Rep {
    subscript<A>() -> Rep<A> where T == () -> A {
        return Rep<A>(.apply(expression, []))
    }
    
    subscript<A, B>(arg: Rep<A>) -> Rep<B> where T == (A) -> B {
        return Rep<B>(.apply(expression, [arg.expression]))
    }
    
    subscript<A, B, C>(arg0: Rep<A>,
                       arg1: Rep<B>) -> Rep<C> where T == (A, B) -> C {
                        return Rep<C>(.apply(expression, [arg0.expression, arg1.expression]))
    }
    
    subscript<A, B, C, D>(arg0: Rep<A>,
                          arg1: Rep<B>,
                          arg2: Rep<C>) -> Rep<D> where T == (A, B, C) -> D {
                            return Rep<D>(.apply(expression, [arg0.expression,
                                                              arg1.expression,
                                                              arg2.expression]))
    }
}

extension Rep : ExpressibleByIntegerLiteral {
    init(integerLiteral value: IntegerLiteralType) {
        self.init(.int(value))
    }
}

extension Rep : ExpressibleByFloatLiteral {
    init(floatLiteral value: FloatLiteralType) {
        self.init(.float(Float(value)))
    }
}

extension Rep : ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self.init(.bool(value))
    }
}

extension Rep : ExpressibleByUnicodeScalarLiteral {
    init(unicodeScalarLiteral value: UnicodeScalar) {
        self.init(.symbol(value))
    }
}

extension Rep : ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(.symbol(value))
    }
}

extension Rep : ExpressibleByArrayLiteral {
    // FIXME: This is broken/hacky, fix with conditional conformance?
    init(arrayLiteral elements: Primitive...) {
        self.init(.array(elements))
    }
}

extension Rep {
    func evaluated<A>() -> T where T == () -> A {
        let fn = try! expression.evaluated(in: [:]) as! ([Any]) -> Any
        return { fn([]) as! A }
    }
    
    func evaluated<A, B>() -> T where T == (A) -> B {
        let fn = try! expression.evaluated(in: [:]) as! ([Any]) -> Any
        return { (x: A) in fn([x as Any]) as! B }
    }
    
    func evaluated<A, B, C>() -> T where T == (A, B) -> C {
        let fn = try! expression.evaluated(in: [:]) as! ([Any]) -> Any
        return { (x: A, y: B) in fn([x as Any, y as Any]) as! C }
    }
    
    func evaluated<A, B, C, D>() -> T where T == (A, B, C) -> D {
        let fn = try! expression.evaluated(in: [:]) as! ([Any]) -> Any
        return { (x: A, y: B, z: C) in fn([x as Any, y as Any, z as Any]) as! D }
    }
}

extension Rep where T : Primitive {
    func evaluated() -> T {
        return try! expression.evaluated(in: [:]) as! T
    }
}

extension Rep {
    func evaluated<A>() -> T where T == Array<A> {
        return try! expression.evaluated(in: [:]) as! T
    }
    
    func map<A, B>(_ fn: Rep<(A) -> B>) -> Rep<[B]> where T == Array<A>, B: Primitive {
        return Rep<[B]>(.map(fn.expression, expression))
    }
    
    func reduce<A, B>(_ fn: Rep<(A, A) -> B>, _ start: Rep<B>) -> Rep<B> where T == Array<A>, B: Primitive {
        return Rep<B>(.reduce(fn.expression, start.expression, expression))
    }
}

func arg<T>(_ symbol: AnyHashable, as type: T.Type = T.self) -> Rep<T> {
    return Rep(.symbol(symbol))
}

func `if`<T>(_ condition: Rep<Bool>, then: Rep<T>, else: Rep<T>) -> Rep<T> {
    return Rep(.if(condition.expression, then.expression, `else`.expression))
}

/// Trivial test
let x: Rep<Int> = 3
let y: Rep<Int> = 9
let z = x * y
z.evaluated()

/// Non-recursive closures working
let addOne: Rep<(Float) -> Float> = lambda(1, in: arg(1) + 1.0)
addOne[1.0].evaluated()
addOne.evaluated()(1)

let subtract: Rep<(Float, Float) -> Float> = lambda((1, 2), in: arg(1) - arg(2))
subtract[3.0, 6.7].evaluated()
subtract.evaluated()(3, 6.7)

let rounded: Rep<Float> = `if`(z != x, then: 1.0, else: 0.0)
rounded.evaluated()
let delayedRounded: Rep<() -> Float> = lambda(in: rounded)
delayedRounded.evaluated()()

/// Control flow working
let round: Rep<(Float) -> Float> =
    lambda("x", in: `if`(0.5 <= ("x" as Rep<Float>), then: 1.0, else: 0.0))
round[0.5].evaluated()
round[0.2].evaluated()
let roundFunc = round.evaluated()
roundFunc(0.5)
roundFunc(0.2)

/// Perceptron
let perceptron: Rep<(Float, Float, Float) -> Float> =
    lambda(("w", "x", "b"), in: "w" * "x" + "b")
let predict = perceptron.evaluated()
predict(0.8, 0.5, 1.0)

/// Map
let array: Rep<[Int]> = [1, 2, 3]
let addFive: Rep<(Int) -> Int> = lambda(1, in: arg(1) + 5)
let isEven: Rep<(Int) -> Bool> = lambda("x", in: ("x" as Rep<Int>) % 2 == 0)
array.evaluated()
array.map(isEven).evaluated()
array.map(addFive).evaluated()
array.map(addFive).map(isEven).evaluated()
array.map(addFive).map(addFive).map(isEven).evaluated()

/// Reduce
let start: Rep<Int> = 5
let add: Rep<(Int, Int) -> Int> = lambda((1, 2), in: arg(1) + arg(2))
array.reduce(add, 0).evaluated()
array.reduce(add, start).evaluated()
array.map(addFive).reduce(add, start).evaluated()

/// TODO: Factorial
func fac(_ x: Rep<Int>) -> Rep<Int> {
    return `if`(x == 0, then: 1, else: fac(x - 1))
}
// fac(0)

// Bug: lack of safety regarding Rep<[T]>, solvable using conditional conformance?

/// New tests

protocol Def {
    associatedtype Result
}

struct LambdaExp<A, B> : Def {
    typealias Result = (A) -> B
    var closure: (Rep<A>) -> Rep<B>
}

func factorial(_ x: Rep<Int>) -> Rep<Int> {
    // it's necessary to unstage the Rep<Bool> here
    if ((x == 1).evaluated()) {
        return 1
    } else {
        return x * factorial(x - 1)
    }
}

let facExp = LambdaExp(closure: factorial)
facExp.closure(6)
facExp.closure(6).evaluated()

func convoluted(_ x: Rep<Int>) {
    func f(_ y: Rep<Int>) {
        return convoluted(y)
    }
    let g = f
    g(x)
}

// convoluted(1)
