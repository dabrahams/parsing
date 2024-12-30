struct SimpleNFA<Symbol: Hashable>: MutableNFA {

  typealias EdgeLabel = EpsilonOr<Symbol>
  typealias State = Int
  typealias OutgoingEdges = [LabeledAdjacencyEdge<EdgeLabel, State>]

  var start: State { 0 }
  var outgoing: [OutgoingEdges] = [[]]
  var accepting: Set<State> = []
  var states: Range<Int> { outgoing.indices }

  func isAccepting(_ s: State) -> Bool { accepting.contains(s) }

  func outgoingEdges(_ s: State) -> OutgoingEdges { outgoing[s] }

  mutating func addState() -> State {
    defer { outgoing.append([]) }
    return outgoing.count
  }

  mutating func addEdge(from source: State, to target: State, via label: EdgeLabel) {
    outgoing[source].append(LabeledAdjacencyEdge(label: label, target))
  }

  mutating func setAccepting(_ s: State) { accepting.insert(s) }

}
