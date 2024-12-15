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
      maybeQuantify((tail, newTail), consumingFirstOf: &s)
      tail = newTail
    }
    return (start, tail)
  }

  mutating func maybeQuantify(_ x: SubExpression, consumingFirstOf s: inout Substring) {
    guard let q = s.first, "?*+".contains(q) else { return }
    if "?*".contains(q) {
      addEdge(from: x.start, to: x.end, via: .epsilon)
    }
    if "+*".contains(q) {
      addEdge(from: x.end, to: x.start, via: .epsilon)
    }
    s.removeFirst()
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

  // Tricksy
  "x(|y)z": [("xyyz", false), ("xz", true), ("xyz", true), ("x", false)],
  "x(y|)z": [("xyyz", false), ("xz", true), ("xyz", true), ("x", false)],
]


@Test func nfaToDfa() async throws {

  for (pattern, expectations) in regularCases {
    let n = TestNFA(pattern)
    let d = EquivalentDFA(n)
    let m = MinimizedDFA(d)
    #expect(m.states.count <= d.states.count, "pattern: \(pattern)")
    for (input, expectedMatch) in expectations {
      #expect(n.recognizes(input) == expectedMatch, "pattern: \(pattern), input: \(input), nfa:\n\(n)")
      #expect(d.recognizes(input) == expectedMatch, "pattern: \(pattern), input: \(input), dfa:\n\(d)")
      #expect(m.recognizes(input) == expectedMatch, "pattern: \(pattern), input: \(input), minimized dfa:\n\(m)")
    }
  }
}
