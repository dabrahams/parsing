import Testing
@testable import parsing

struct TestNFA: NFA {
  typealias Symbol = Character
  typealias State = Int
  typealias OutgoingEdges = [LabeledAdjacencyEdge<EdgeLabel, State>]

  var start: State { 0 }
  var outgoing: Dictionary<State, OutgoingEdges> = [:]
  var accepting: Set<State> = []
  var stateCount = 1
  var states: Range<Int> { 0..<stateCount }

  func isAccepting(_ s: State) -> Bool { accepting.contains(s) }

  func outgoingEdges(_ s: State) -> OutgoingEdges { outgoing[s] ?? [] }

  mutating func addState() -> State {
    defer { stateCount += 1}
    return stateCount
  }

  mutating func addEdge(from source: State, to target: State, via label: EdgeLabel) {
    outgoing[source, default: []].append(LabeledAdjacencyEdge(label: label, target))
  }

  typealias SubExpression = (start: State, end: State)

  /// Appends states for a regex containing no top-level "|" symbols, stopping at the first "|" or unmatched ")"
  mutating func append(to start: State, consumingRegexAlternative s: inout Substring) -> SubExpression {
    // This epsilon transition is needed to keep the tricksy test
    // cases working.  Otherwise an alternative path to the empty
    // language will end up being a loop, since start == end for the
    // NFA recognizing the empty pattern.
    var tail = addState()
    addEdge(from: start, to: tail, via: .epsilon)

    while let c = s.first {
      if "|)".contains(c) { return (start, tail) }
        s.removeFirst()

      let newTail: State
      if c == "(" {
        newTail = append(to: tail, consumingRegex: &s).end
        precondition(s.first == ")", "missing close paren")
        s.removeFirst()
      }
      else {
        // Single symbol
        precondition(!"?+*".contains(c), "invalid regex; unexpected quantifier")
        newTail = addState()
        addEdge(from: tail, to: newTail, via: .some(c))
      }
      tail = maybeQuantify((tail, newTail), consumingFirstOf: &s)
    }
    return (start, tail)
  }

  mutating func maybeQuantify(_ x: SubExpression, consumingFirstOf s: inout Substring) -> State {
    guard let q = s.first, "?*+".contains(q) else { return x.end }
    s.removeFirst()
    if "?*".contains(q) {
      // Allow skipping forward over x
      addEdge(from: x.start, to: x.end, via: .epsilon)
    }
    if "+*".contains(q) {
      // Allow looping back to recognize x again
      addEdge(from: x.end, to: x.start, via: .epsilon)
      let r = addState()

      // Without this forward ɛ-edge, consecutive quantifications
      // could be hopped over backward.  turning "x*y*" into "(x|y)*".
      addEdge(from: x.end, to: r, via: .epsilon)
      return r
    }
    return x.end
  }

  mutating func append(to start: State, consumingRegex s: inout Substring) -> SubExpression {
    let term = append(to: start, consumingRegexAlternative: &s)
    while s.first == "|" {
      s.removeFirst()
      let alternative = append(to: start, consumingRegexAlternative: &s)
      addEdge(from: alternative.end, to: term.end, via: .epsilon)
    }
    return term
  }

  init(_ r: String) {
    accepting = []
    var s = r[...]
    let exp = append(to: start, consumingRegex: &s)
    precondition(s.isEmpty,  "unexpected unconsumed regex input: \(s)" )
    accepting = [exp.end]
  }
}

extension TestNFA: CustomStringConvertible {

  var description: String {
    let rows = states.map {
      "\($0): \(outgoingEdges($0).sortedIfPossible().map { e in "\(e.label)->\(e.otherEnd)" }.joined(separator: " "))" }

    return
      """
      start: \(start); accepting: \(states.filter(isAccepting).sortedIfPossible())
      \(rows.joined(separator: "\n"))
      """
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

@Test func nfaToDfa() async throws {

  for (pattern, expectations) in regularCases {
    let n = TestNFA(pattern)
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
}

/*
@Test func console() async throws {

  let n = TestNFA("(xyz|xy*)z+")
  print(n)
  var r = TestNFA.Recognizer(recognizing: n)
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
