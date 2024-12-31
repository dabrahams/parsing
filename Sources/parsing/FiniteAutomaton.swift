protocol FiniteAutomaton<EdgeLabel>: CustomStringConvertible {

  associatedtype EdgeLabel: Equatable
  associatedtype State: Hashable
  associatedtype OutgoingEdges: Collection<LabeledAdjacencyEdge<EdgeLabel, State>>
  associatedtype States: Collection<State>

  var start: State { get }
  var states: States { get }

  func isAccepting(_ s: State) -> Bool
  func outgoingEdges(_ s: State) -> OutgoingEdges

}

extension FiniteAutomaton {

  var description: String {
    let rows = states.sortedIfPossible().map {
      "\($0): \(outgoingEdges($0).sortedIfPossible().map { e in "\(e.label)->\(e.otherEnd)" }.joined(separator: " "))" }

    return
      """
      start: \(start); accepting: \(states.filter(isAccepting).sortedIfPossible())
      \(rows.joined(separator: "\n"))
      """
  }

}
