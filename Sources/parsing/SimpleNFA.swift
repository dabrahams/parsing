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


extension SimpleNFA: CustomStringConvertible {

  var description: String {
    let rows = states.map {
      "\($0): \(outgoingEdges($0).sortedIfPossible().map { e in "\(e.label)->\(e.otherEnd)" }.joined(separator: " "))" }

    return
      """
      start: \(start); accepting: \(states.filter(isAccepting).sortedIfPossible())
      \(rows.joined(separator: "\n"))
      """
  }

}
