extension DFA {
  
  /// Return the sets of equivalent states for DFA minimization.
  ///
  /// - Algorithm due to Hopcroft.
  /// - Complexity: O(ns log n), where n is the number of states and s
  ///   is the size of the alphabet
  func stateEquivalenceSets() -> Set<Set<State>> {
    var incomingEdges: [State: [EdgeLabel: [State]]] = [:]
    for s in states {
      for e in outgoingEdges(s) {
        incomingEdges[e.otherEnd, default: [:]][e.label, default: []].append(s)
      }
    }
    func incoming(to s: State, on c: EdgeLabel) -> [State] {
      incomingEdges[s].flatMap { $0[c] } ?? []
    }

    let q = Set(states)
    let f = q.filter { isAccepting($0) }
    // P := {F, Q \ F}
    let nonAcceptingStates = q.subtracting(f)
    var p: Set<Set<State>> = Set([f, nonAcceptingStates].lazy.filter { !$0.isEmpty })
    // W := {F, Q \ F}
    var w = p

    // while (W is not empty) do
    //     choose and remove a set A from W
    while let a = w.popFirst() {

      // for each c in Σ do
      let incomingLabels = Set<EdgeLabel>(
        a.lazy.flatMap { incomingEdges[$0, default: [:]].keys })
      for c in incomingLabels {

        // let X be the set of states for which a transition on c leads to a state in A
        let x: Set<State> = Set(a.lazy.flatMap { incoming(to: $0, on: c) })

        // for each set Y in P for which X ∩ Y is nonempty and Y \ X is nonempty do
        for y in p {
          let intersection = x.intersection(y)
          if intersection.isEmpty { continue }
          let difference = y.subtracting(x)
          if difference.isEmpty { continue }

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
    return p
  }
}

struct MinimizedDFA<Source: DFA>: DFA {

  typealias Symbol = Source.Symbol
  typealias State = Source.State
  typealias EdgeLabel = Symbol
  typealias OutgoingEdges = Array<LabeledAdjacencyEdge<EdgeLabel, State>>
  typealias States = [State]
  var start: State

  var source: Source
  var states: States
  var fromSource: [Source.State: State] = [:]

  init(_ source: Source) {
    self.source = source
    let fatStates = source.stateEquivalenceSets()
    states = fatStates.map { $0.first! }
    for s in fatStates {
      for s0 in s {
        fromSource[s0] = s.first!
      }
    }
    start = fromSource[source.start]!
  }

  func isAccepting(_ s: State) -> Bool {
    source.isAccepting(s)
  }

  func outgoingEdges(_ s: State) -> OutgoingEdges {
    source.outgoingEdges(s).map { .init(label: $0.label, fromSource[$0.otherEnd]!) }
  }

  func successor(of s: State, via label: EdgeLabel) -> Optional<State> {
    source.successor(of: s, via: label).map {
      fromSource[$0]! 
    }
  }

}

extension DFA {

  func minimized() -> SmallDFA<Symbol> {

    SmallDFA(MinimizedDFA(self))

  }

}
