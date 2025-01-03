import Collections

protocol SmallIntStateDFA<EdgeLabel>: DFA where State == Int {

  associatedtype AcceptingSet: SetAlgebra where AcceptingSet.Element == State

  var graph: [[EdgeLabel: State]] { get }
  var accepting: AcceptingSet { get }

}

extension SmallIntStateDFA {

  func isAccepting(_ s: Int) -> Bool { accepting.contains(s) }

  func outgoingEdges(_ s: State) -> LazyMapCollection<[Symbol: Int], LabeledAdjacencyEdge<Symbol, Int>> {
    graph[s].lazy.map { (k, v) in .init(label: k, v) }
  }

  func successor(of s: State, via label: EdgeLabel) -> Optional<State> {
    graph[s][label]
  }

}

protocol MutableSmallIntStateDFA: SmallIntStateDFA, MutableDFA {

  var graph: [[EdgeLabel: State]] { get set }
  var accepting: BitSet { get set }

}

extension MutableSmallIntStateDFA {

  mutating func setAccepting(_ s: Int) { accepting.insert(s) }

  mutating func addEdge(from source: State, to target: State, via label: EdgeLabel) {
    assert(graph[source][label] == nil)
    graph[source][label] = target
  }

  mutating func addState() -> State {
    defer { graph.append([:]) }
    return graph.count
  }

}
