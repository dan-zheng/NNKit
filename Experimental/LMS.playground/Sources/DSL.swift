//: ### DSL

public typealias Rep<Result> = Expression<Result>

public extension Rep {
    func evaluated() -> Result {
        return evaluated(in: Environment(parent: nil))
    }
}

prefix operator ^

public prefix func ^(_ value: Int) -> Rep<Int> {
    return ConstantExpression(value: value)
}

public prefix func ^(_ value: Float) -> Rep<Float> {
    return ConstantExpression(value: value)
}

public prefix func ^(_ value: Bool) -> Rep<Bool> {
    return ConstantExpression(value: value)
}

public prefix func ^(_ value: [Int]) -> Rep<[Int]> {
    return ConstantExpression(value: value)
}

public prefix func ^(_ value: [Float]) -> Rep<[Float]> {
    return ConstantExpression(value: value)
}

public prefix func ^(_ value: [Bool]) -> Rep<[Bool]> {
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
}

public func lambda<Argument, Result>(
    file: StaticString = #file, line: UInt = #line, column: UInt = #column,
    _ closure: @escaping (Rep<Argument>) -> Rep<Result>) -> Rep<(Argument) -> Result> {
    let loc = SourceLocation(file: file, line: line, column: column)
    return LambdaExpression(closure: closure, location: loc)
}

// TODO: Add support for lambda with multiple args

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
    func map<Argument, Return>(_ fn: Rep<(Argument) -> Return>) -> Rep<[Return]> where Result == [Argument] {
        return MapExpression<Argument, Return>(closure: fn, sequence: self)
    }

    func reduce<Argument, Return>(_ fn: Rep<(Return) -> (Argument) -> Return>, _ acc: Rep<Return>) -> Rep<Return> where Result == [Argument] {
        return ReduceExpression(closure: fn, accumulator: acc, sequence: self)
    }

    /*
    func reduce<Argument, Return>(_ fn: Rep<(Return, Argument) -> Return>, _ acc: Rep<Return>) -> Rep<Return> where Result == [Argument] {
        return ReduceExpression(closure: fn, accumulator: acc, sequence: self)
    }
    */
}
