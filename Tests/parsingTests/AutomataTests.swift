import Testing
@testable import parsing

extension MutableNFA where Symbol == Character {

  init(parsing pattern: String) throws {
    let r = try RegularExpression<Character>(pattern)
    self = .init()
    let endState = r.build(into: &self, at: start)
    self.setAccepting(endState)
  }

}

let regularCases: [String: [(input: String, expected: Bool)]] = [
  // Basic cases
  "": [("", true), ("x", false), ("xy", false)],
  "x": [("", false), ("x", true), ("xy", false)],
  "x+": [("", false), ("x", true), ("xy", false), ("xx", true)],
  "x*": [("", true), ("x", true), ("xy", false), ("xx", true)],
  "x?": [("", true), ("x", true), ("xy", false), ("xx", false)],
  "x|y": [("", false), ("x", true), ("y", true), ("xx", false)],

  // Nested groups
  "(xy)+": [("", false), ("xy", true), ("xyxy", true), ("x", false)],
  "(x|y)*": [("", true), ("x", true), ("y", true), ("xy", true), ("yx", true), ("xyxy", true)],
  
  // Complex combinations
  "x(y|z)+": [("", false), ("x", false), ("xy", true), ("xz", true), ("xyz", true), ("xyzyz", true)],
  "(ab|cd)*": [("", true), ("ab", true), ("cd", true), ("abcd", true), ("cdab", true), ("abc", false)],
  
  // Multiple alternatives
  "a|b|c": [("", false), ("a", true), ("b", true), ("c", true), ("d", false), ("ab", false)],
  "(x|y)(a|b)": [("xa", true), ("xb", true), ("ya", true), ("yb", true), ("xx", false), ("ab", false)],

  // Double nesting
  "((x|y)z)+": [("xa", false), ("xy", false), ("xz", true), ("yz", true), ("xzx", false), ("xzyy", false), ("xzyz", true)],

  // Regression tests
  "x(|y)z": [("xyyz", false), ("xz", true), ("xyz", true), ("x", false)],
  "x(y|)z": [("xyyz", false), ("xz", true), ("xyz", true), ("x", false)],
  "xyzzyq|x*y+q": [("xyzxy", false), ("yxyq", false), ("xyzzyq", true), ("yyq", true), ("xq", false), ("q", false), ("xyq", true)],
]

@Test(arguments: regularCases) func nfaToDfa(pattern: String, expectations: [(input: String, expected: Bool)]) async throws {

  let n = try SimpleNFA(parsing: pattern)
  let d = SmallDFA(EquivalentDFA(n)) // small makes it easier to read.
  let m = MinimizedDFA(d)
  #expect(m.states.count <= d.states.count,
          """

            pattern: \(pattern)
            ---- DFA ---
            \(d)
            ---- MINIMIZED ---
            \(m)

            """
  )

  for (input, expectedMatch) in expectations {
    #expect(n.recognizes(input) == expectedMatch, "pattern: \(pattern), input: \(input), nfa:\n\(n)")
    #expect(d.recognizes(input) == expectedMatch, "pattern: \(pattern), input: \(input), dfa:\n\(d)")
    #expect(m.recognizes(input) == expectedMatch,
            """

              pattern: \(pattern), input: \(input)
              ---- DFA ---
              \(d)
              ---- MINIMIZED ---
              \(m)

              """
    )
  }
}

/*
@Test func console() async throws {

  let n = SimpleNFA("(xyz|xy*)z+")
  print(n)
  var r = SimpleNFA.Recognizer(recognizing: n)
  print(r.configuration)
  _ = r.consume("x")
  print(r.configuration)
  _ = r.consume("y")
  print(r.configuration)
  _ = r.consume("y")
  print(r.configuration)
  _ = r.consume("z")
  print(r.configuration)
  print(r.currentAcceptingStates())

  let d = SmallDFA(EquivalentDFA(n))
  print(d)
  let m = MinimizedDFA(d)
  print(m)

}
*/