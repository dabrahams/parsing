protocol MutableFiniteAutomaton: FiniteAutomaton {

  init()

  mutating func addState() -> State
  mutating func addEdge(from source: State, to target: State, via label: EdgeLabel)
  mutating func setAccepting(_ s: State)

}

extension MutableFiniteAutomaton {

  mutating func insertGraph<Source: FiniteAutomaton>(
    _ source: Source, mapLabel : (Source.EdgeLabel)->EdgeLabel
  ) -> [Source.State: State]
  {
    var localID: [Source.State: State] = [:]

    for s in source.states {
      let n = addState()
      localID[s] = n
    }

    for s in source.states {
      let n = localID[s]!
      for e in source.outgoingEdges(s) {
        addEdge(from: n, to: localID[e.otherEnd]!, via: mapLabel(e.label))
      }
    }

    return localID
  }

}
