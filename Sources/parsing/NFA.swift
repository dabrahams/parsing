protocol NFA {
  associatedtype Symbol: Hashable
  typealias EdgeLabel = EpsilonOr<Symbol>
  associatedtype State: Hashable
  associatedtype OutgoingEdges: Collection where OutgoingEdges.Element == LabeledAdjacencyEdge<EdgeLabel, State>

  var start: State { get }
  func isAccepting(_ s: State) -> Bool
  func outgoingEdges(_ s: State) -> OutgoingEdges
}

extension NFA {

  /// Returns `true` iff `self` recognizes the string of symbols in `w`.
  func recognizes<Word: Collection<Symbol>>(_ w: Word) -> Bool {
    !acceptingStates(w).isEmpty
  }

  /// Returns the set of accepting states reached by recognizing the
  /// string of symbols in `w`, or `[]` if `w` is not recognized.
  func acceptingStates<Word: Collection<Symbol>>(_ w: Word) -> Set<State> {
    typealias Configuration = Set<State>
    var current: Configuration = epsilonClosure([start])
    for c in w {
      var next: Configuration = []

      for s in current {
        for e in outgoingEdges(s) where e.label == c {
          next.insert(e.otherEnd)
        }
      }
      if next.isEmpty { return [] }
      current = epsilonClosure(next)
    }
    return current.filter(isAccepting)
  }

  func epsilonClosure(_ s: Set<State>) -> Set<State> {
    var r: Set<State> = []
    var q: Set<State> = s

    while let v = q.popFirst() {
      if r.insert(v).inserted {
        for e in outgoingEdges(v) where e.label == .epsilon {
          q.insert(e.otherEnd)
        }
      }
    }
    return r
  }
}
