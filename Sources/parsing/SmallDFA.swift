struct SmallDFA<Symbol: Hashable>: DFA {
  typealias EdgeLabel = Symbol
  typealias State = Int
  typealias OutgoingEdges = LazyMapCollection<[Symbol: Int], LabeledAdjacencyEdge<Symbol, Int>>
  typealias States = Range<Int>

  let graph: [[Symbol: Int]]
  let start: Int
  let accepting: Set<Int>
  var states: Range<Int> { 0..<graph.count }

  init<Source: DFA<Symbol>>(_ source: Source) {
    var g: [[Symbol: Int]] = []
    var inverse: [Source.State: Int] = [:]

    for s in source.states {
      let n = g.count
      g.append([:])
      inverse[s] = n
    }

    for s in source.states {
      let n = inverse[s]!
      for e in source.outgoingEdges(s) {
        g[n][e.label] = inverse[e.otherEnd]
      }
    }
    graph = g
    start = inverse[source.start]!
    self.accepting = Set(source.states.lazy.filter { source.isAccepting($0) }.map { inverse[$0]! })
  }

  func isAccepting(_ s: State) -> Bool { accepting.contains(s) }
  func outgoingEdges(_ s: State) -> OutgoingEdges {
    graph[s].lazy.map { (k, v) in .init(label: k, v) }
  }

  func successor(of s: State, via label: EdgeLabel) -> Optional<State> {
    graph[s][label]
  }
}
