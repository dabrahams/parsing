struct EquivalentDFA<N: NFA>: DFA {
  typealias Symbol = N.Symbol
  typealias State = Set<N.State>
  typealias EdgeLabel = Symbol
  typealias OutgoingEdges = Array<LabeledAdjacencyEdge<EdgeLabel, State>>
  typealias States = Set<State>

  var source: N
  var states: States = []
  var outgoingEdges: Dictionary<State, Dictionary<EdgeLabel, State>> = [:]

  func isAccepting(_ s: State) -> Bool {
    !s.allSatisfy { !source.isAccepting($0) }
  }

  func outgoingEdges(_ s: State) -> OutgoingEdges {
    outgoingEdges[s].map { $0.map { (k, v) in .init(label: k, v) } } ?? []
  }

  func successor(of s: State, via label: EdgeLabel) -> Optional<State> {
    outgoingEdges[s].flatMap { $0[label] }
  }
  
  let start: State

  init(_ source: N) {
    self.source = source
    self.start = source.epsilonClosure([source.start])

    // Work list
    var q: Set<State> = [start]

    while let s = q.popFirst() {
      // Skip states we've processed
      if !states.insert(s).inserted { continue }

      // Accumulator for outgoing edges of s.
      var outEdges = Dictionary<EdgeLabel, State>()

      // Follow each non-epsilon edge out of an NFA state in s
      for ns in s {
        for e in source.outgoingEdges(ns) where e.label != .epsilon {
          // Add target to set of NFA states reachable directly by the same label from s.
          outEdges[e.label.symbol, default: []].insert(e.otherEnd)
        }
      }
      
      for (label, t) in outEdges {
        let target = source.epsilonClosure(t)
        // Make sure a DFA state is processed for each target NFA set
        q.insert(target)

        // Record an edge in the DFA for each edge label discovered on
        // an edge from an NFA state in s.
        outgoingEdges[s, default: [:]][label] = target
      }
    }
  }
}

extension EquivalentDFA: CustomStringConvertible {
  var description: String {
    "\(outgoingEdges)\nstart: \(start); accepting: \(states.filter(isAccepting))"
  }
}
