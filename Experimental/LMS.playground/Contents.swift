//: ## Light-lightweight Modular Staging in Swift
//: References:
//: 1. [Scala LMS tutorials](https://scala-lms.github.io/tutorials)
//: 2. [T. Rompf and M. Odersky, "Lightweight Modular Staging: A Pragmatic Approach to Runtime Code Generation and Compiled DSLs"](https://infoscience.epfl.ch/record/150347/files/gpce63-rompf.pdf)

let x = ^10.0
let y = ^20.0
(x + y).evaluated()

let addTen = lambda { x in
    x + ^10
}
addTen.evaluated()(10)

let round = lambda { x in
    `if`(x >= ^0.5, then: ^1.0, else: ^0.0)
}
round[^0.3].evaluated()
round[^0.73].evaluated()

let curriedAdd: Rep<(Float) -> (Float) -> Float> =
    lambda { x in lambda { y in x + y } }
curriedAdd[x][y].evaluated()

/// Direct recursion
func factorial(_ n: Rep<Int>) -> Rep<Int> {
    return `if`(n == ^0, then: ^1, else: n * factorial(n - ^1))
}
factorial(^0).evaluated()
factorial(^20).evaluated()
factorial(^5)

/// Indirect recursion (preferred, always staged once!)
func factorialIndirect(_ n: Rep<Int>) -> Rep<Int> {
    let next = lambda { n in n * factorial(n - ^1) }
    return `if`(n == ^0, then: ^1, else: next[n])
}
factorialIndirect(^0).evaluated()
factorialIndirect(^1).evaluated()
factorialIndirect(^20).evaluated()

func fibonacci(_ n: Rep<Int>) -> Rep<Int> {
    let next = lambda { n in fibonacci(n - ^1) + fibonacci(n - ^2) }
    return cond(n == ^0, ^0,
                n == ^1, ^1,
                else: next[n])
}
fibonacci(^12).evaluated()

/// HOF
let apply = lambda { (f: Rep<(Int) -> Int>) in
    lambda { x in f[x] }
}
apply[addTen][^20].evaluated()
