//
//  LMS.playground
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

//: ## Light-lightweight Modular Staging in Swift
//: References:
//: 1. [Scala LMS tutorials](https://scala-lms.github.io/tutorials)
//: 2. [T. Rompf and M. Odersky, "Lightweight Modular Staging: A Pragmatic Approach to Runtime Code Generation and Compiled DSLs"](https://infoscience.epfl.ch/record/150347/files/gpce63-rompf.pdf)

//: `^` : the magical operator that stages everything.
//: `x.evaluated()` reifys `Rep<T>` to `T`
let x = ^10.0   // Rep<Float>
let y = ^20.0   // Rep<Float>
let z = x + y   // Rep<Float>
z.evaluated()   // Float

//: Embedded function syntax, staged when taking arguments
func timesFive(_ x: Rep<Int>) -> Rep<Int> {
    return x * ^5
}
timesFive(^10).evaluated()

//: Lambda abstraction and staged function application (`f[x]`)
let addTen = lambda { x in x + ^10 }
let stagedResult = addTen[^10]
stagedResult.evaluated()

//: Control flow
let round = lambda { x in
    `if`(x >= ^0.5, then: ^1.0, else: ^0.0)
}
round[^0.3].evaluated()
round[^0.73].evaluated()

//: Applying a curried staged function to multiple args
let curriedAdd: Rep<(Float) -> (Float) -> Float> =
    lambda { x in
        lambda { y in
            x + y
        }
    }
curriedAdd[x][y].evaluated()

//: Reify a staged function to a host function
let abs: Rep<(Int) -> Int> = lambda { x in
    `if`(x > ^0, then: x, else: -x)
}
let reifiedAbs: (Int) -> Int = abs.evaluated()
reifiedAbs(-100)

//: Direct (just-in-time staged) recursion by lazy evaluation in the
//: host language
func factorialDirect(_ n: Rep<Int>) -> Rep<Int> {
    return `if`(n == ^0, then: ^1, else: n * factorialDirect(n - ^1))
}
factorialDirect(^0).evaluated()
factorialDirect(^20).evaluated()
factorialDirect(^5)

//: Single-staged recursion, the most efficient recursion, internally
//: done by checking functions' intentional equivalence. Closures defined
//: at a specific source location gets staged (or codegen'ed) exactly
//: once and reused throughout the program.
func factorial(_ n: Rep<Int>) -> Rep<Int> {
    let next = lambda { n in n * factorial(n - ^1) }
    return `if`(n == ^0, then: ^1, else: next[n])
}
factorial(^0).evaluated()
factorial(^1).evaluated()
factorial(^20).evaluated()

func fibonacci(_ n: Rep<Int>) -> Rep<Int> {
    let next = lambda { n in
        fibonacci(n - ^1) + fibonacci(n - ^2)
    }
    return cond(n == ^0, ^0,
                n == ^1, ^1,
                else: next[n])
}
fibonacci(^12).evaluated()

//: Staged higher-order functions
let apply = lambda { (f: Rep<(Int) -> Int>) in
    lambda { x in f[x] }
}
apply[addTen][^20].evaluated()

//: Higher-order functions on collections
let double = lambda { x in x * ^2.0 }
let arr = ^[1.0, 2.0, 3.0]
arr.map(double).evaluated()
arr.map(double).map(double).evaluated()

//: ### Experiments

