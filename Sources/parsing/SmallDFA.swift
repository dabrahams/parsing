import Collections

struct SmallDFA<Symbol: Hashable>: MutableSmallIntStateDFA {

  typealias EdgeLabel = Symbol
  typealias States = Range<Int>

  var graph: [[Symbol: Int]] = [[:]]
  var accepting: BitSet = []
  var start: Int = 0
  var states: Range<Int> { 0..<graph.count }

  /// An instance with a single start state 0 and no accepting states.
  init() {}

  /// An instance isomorphic to source.
  init<Source: DFA<Symbol>>(_ source: Source) {
    graph = []
    let localState = insertGraph(source, mapLabel: { $0 })
    start = localState[source.start]!
    self.accepting = BitSet(
      source.states.lazy.filter { source.isAccepting($0) }.map { localState[$0]! })
  }

}
