extension DFA {
  
  /// Return the equivalent states for DFA minimization.
  ///
  /// Algorithm due to Hopcroft.
  func stateEquivalenceSets() -> Set<Set<State>> {
    print("---------")
    var incomingEdges: [State: [EdgeLabel: [State]]] = [:]
    for s in states {
      for e in outgoingEdges(s) {
        incomingEdges[e.otherEnd, default: [:]][e.label, default: []].append(s)
      }
    }
    func incoming(to s: State, on c: EdgeLabel) -> [State] {
      incomingEdges[s].flatMap { $0[c] } ?? []
    }

    print("incoming:", incomingEdges)

    let q = Set(states)
    let f = q.filter { isAccepting($0) }
    // P := {F, Q \ F}
    var p: Set<Set<State>> = Set([f, q.subtracting(f)])
    // W := {F, Q \ F}
    var w = p

    print("start, W:", w)
    // while (W is not empty) do
    //     choose and remove a set A from W
    while let a = w.popFirst() {

      print("popped", a)

      // for each c in Σ do
      let incomingLabels = Set<EdgeLabel>(
        a.lazy.flatMap { incomingEdges[$0, default: [:]].keys })
      for c in incomingLabels {
        print("---")
        print("c: ", c)

        // let X be the set of states for which a transition on c leads to a state in A
        let x: Set<State> = Set(a.lazy.flatMap { incoming(to: $0, on: c) })
        print("x:", x)

        // for each set Y in P for which X ∩ Y is nonempty and Y \ X is nonempty do
        for y in p {
          print("y:", y)
          let intersection = x.intersection(y)
          if intersection.isEmpty { continue }
          let difference = y.subtracting(x)
          if difference.isEmpty { continue }
	  print("intersection:", intersection)
	  print("difference:", intersection)

          // replace Y in P by the two sets X ∩ Y and Y \ X
          p.remove(y)
          p.formUnion([intersection, difference])

          // if Y is in W
          if w.remove(y) != nil {
            print("y found; replace with intersection/difference")
            // replace Y in W by the same two sets
            w.formUnion([intersection, difference])
          }
          else {
            print("y not found; add the smaller of intersection/difference")
            // if |X ∩ Y| <= |Y \ X| add X ∩ Y to W else add Y \ X to W
            w.insert(intersection.count <= difference.count ? intersection : difference)
          }
        }
      }
    }
    print("done:", p)
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

extension MinimizedDFA: CustomStringConvertible {

  var description: String {
    let rows = states.map {
      "\($0): \(source.outgoingEdges($0).map { e in "\(e.label)->\(e.otherEnd)" }.joined(separator: " "))" }

    return
      """
      start: \(start); accepting: \(states.filter(isAccepting))
      \(rows.joined(separator: "\n"))
      """
  }

}
