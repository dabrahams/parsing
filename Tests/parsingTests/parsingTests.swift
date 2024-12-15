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
  mutating func append(to start: State, consumingRegexTerm s: inout Substring) -> SubExpression {
    var tail = start
    while let c = s.first {
      if "|)".contains(c) { return (start, tail) }

      let newTail: State
      if c == "(" {
        newTail = append(to: start, consumingRegex: &s).end
      }
      else {
        // Single symbol
        precondition(!"?+*".contains(c), "invalid regex; unexpected quantifier")
        s.removeFirst()
        newTail = addState()
        addEdge(from: start, to: newTail, via: .some(c))
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
    guard let c = s.first else {
      let end = addState()
      addEdge(from: start, to: end, via: .epsilon)
      return (start, end)
    }

    if c == ")" { return (start, start) }

    // Parenthesized subexpression
    if c == "(" {
      s.removeFirst()
      let r = append(to: start, consumingRegex: &s)
      precondition(s.popFirst() == ")", "invalid regex; missing )")
      maybeQuantify(r, consumingFirstOf: &s)
      return r
    }
    else {
      let term = append(to: start, consumingRegexTerm: &s)
      while s.first == "|" {
        s.removeFirst()
        let alternative = append(to: start, consumingRegexTerm: &s)
        addEdge(from: alternative.end, to: term.end, via: .epsilon)
      }
      return term
    }
  }

  init(_ r: String) {
    accepting = []
    var s = r[...]
    let exp = append(to: start, consumingRegex: &s)
    precondition(s.isEmpty,  "unexpected unconsumed regex input: \(s)" )
    accepting = [exp.end]
  }
}


@Test func nfaToDfa() async throws {

  do {
    let n = TestNFA("")
    let d = EquivalentDFA(n)
    for (input, r) in [("", true), ("x", false), ("xy", false)] {
      #expect(n.recognizes(input) == r)
      #expect(d.recognizes(input) == r)
    }
  }

  do {
    let n = TestNFA("x")
    print(n)
    let d = EquivalentDFA(n)
    for (input, r) in [("", false), ("x", true), ("xy", false)] {
      #expect(n.recognizes(input) == r)
      #expect(d.recognizes(input) == r)
    }
  }

    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
}
