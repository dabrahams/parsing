protocol MutableFiniteAutomaton: FiniteAutomaton {

  init()

  mutating func addState() -> State
  mutating func addEdge(from source: State, to target: State, via label: EdgeLabel)
  mutating func setAccepting(_ s: State)

}
