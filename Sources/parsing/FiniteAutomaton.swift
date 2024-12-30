protocol FiniteAutomaton<EdgeLabel> {
  associatedtype EdgeLabel: Equatable
  associatedtype State: Hashable
  associatedtype OutgoingEdges: Collection<LabeledAdjacencyEdge<EdgeLabel, State>>
  associatedtype States: Collection<State>

  var start: State { get }
  var states: States { get }

  func isAccepting(_ s: State) -> Bool
  func outgoingEdges(_ s: State) -> OutgoingEdges
}
