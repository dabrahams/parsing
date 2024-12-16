protocol DFA<Symbol> {
  associatedtype Symbol: Hashable
  typealias EdgeLabel = Symbol
  associatedtype State: Hashable
  associatedtype OutgoingEdges: Collection<LabeledAdjacencyEdge<EdgeLabel, State>>
  associatedtype States: Collection<State>

  var start: State { get }
  var states: States { get }

  func isAccepting(_ s: State) -> Bool
  func outgoingEdges(_ s: State) -> OutgoingEdges
  func successor(of s: State, via label: EdgeLabel) -> Optional<State>
}

extension DFA {

  /// Returns `true` iff `self` recognizes the string of symbols in `w`.
  func recognizes<Word: Collection<Symbol>>(_ w: Word) -> Bool {
    acceptingState(w) != nil
  }

  /// Returns the accepting state reached by recognizing the
  /// string of symbols in `w`, or `nil` if `w` is not recognized.
  func acceptingState<Word: Collection<Symbol>>(_ w: Word) -> Optional<State> {

    var current = start
    for c in w {
      guard let next = successor(of: current, via: c) else { return nil }
      current = next
    }
    return isAccepting(current) ? current : nil
  }

}
