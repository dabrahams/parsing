extension DFA {
  
  /// Return the equivalent states for DFA minimization.
  ///
  /// Algorithm due to Hopcroft.
  func stateEquivalenceSets() -> Set<Set<State>> {
    var incomingEdges: [State: [EdgeLabel: State]] = [:]
    for s in states {
      for e in outgoingEdges(s) {
        incomingEdges[e.otherEnd, default: [:]][e.label] = s
      }
    }
    let incoming = { incomingEdges[$0, default: [:]] }
    
    // P := {F, Q \ F}
    var p: Set<Set<State>> = [
      Set(states.lazy.filter { isAccepting($0) }),
      Set(states.lazy.filter { !isAccepting($0) }) ]
    // W := {F, Q \ F}
    var w = p
    
    // while (W is not empty) do
    //     choose and remove a set A from W
    while let a = w.popFirst() {
      
      // for each c in Σ do
      let incomingLabels = Set(a.lazy.flatMap { incoming($0).keys})
      for c in incomingLabels {
        // let X be the set of states for which a transition on c leads to a state in A
        let x: Set<State> = Set(a.lazy.compactMap { incoming($0)[c] })

        // for each set Y in P for which X ∩ Y is nonempty and Y \ X is nonempty do
        for y in p {
          let intersection = x.intersection(y)
          if !intersection.isEmpty {
            let difference = y.subtracting(x)
            if !difference.isEmpty {
              // replace Y in P by the two sets X ∩ Y and Y \ X
              p.remove(y)
              p.formUnion([intersection, difference])

              // if Y is in W
              if w.remove(y) != nil {
                // replace Y in W by the same two sets
                w.formUnion([intersection, difference])
              }
              else {
                // if |X ∩ Y| <= |Y \ X| add X ∩ Y to W else add Y \ X to W
                w.insert(intersection.count <= difference.count ? intersection : difference)
              }
            }
          }
        }
      }
    }
    return p
  }
}

struct MinimizedDFA<Source: DFA>: DFA {
  typealias Symbol = Source.Symbol
  typealias State = Set<Source.State>
  typealias EdgeLabel = Symbol
  typealias OutgoingEdges = Array<LabeledAdjacencyEdge<EdgeLabel, State>>
  typealias States = Set<State>
  var start: Set<Source.State>

  var source: Source
  var states: States
  var fromSource: [Source.State: State] = [:]

  init(_ source: Source) {
    self.source = source
    states = source.stateEquivalenceSets()
    for s in states {
      for s0 in s {
        fromSource[s0] = s
      }
    }
    start = fromSource[source.start]!
  }

  func isAccepting(_ s: State) -> Bool {
    source.isAccepting(s.first!)
  }

  func outgoingEdges(_ s: State) -> OutgoingEdges {
    source.outgoingEdges(s.first!).map { .init(label: $0.label, fromSource[$0.otherEnd]!) }
  }

  func successor(of s: State, via label: EdgeLabel) -> Optional<State> {
    source.successor(of: s.first!, via: label).map { 
      fromSource[$0]! 
    }
  }

}
