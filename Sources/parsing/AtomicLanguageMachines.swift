import Collections

struct AtomicLanguageMachines<Symbol: Hashable> {

  typealias LanguageID = AtomicLanguage<Symbol>.ID

  enum MergedDFAEdgeLabel: Hashable {
    case normal(Symbol)
    case entryPoint(LanguageID)

    var normal: Symbol? { if case let .normal(x) = self { x } else { nil } }
    var entryPoint: LanguageID? { if case let .entryPoint(x) = self { x } else { nil } }
  }

  var languages: [LanguageID: Language] = [:]

  typealias Vertex = Graph.Index

  typealias Graph = [[Symbol: Int]]
  struct Language: SmallIntStateDFA {
    typealias EdgeLabel = Symbol

    var start: Int
    var states: Set<Int>
    var graph: Graph
    var accepting: Set<Int>
  }

  let mergedDFA: SmallDFA<MergedDFAEdgeLabel>

  subscript(_ l: LanguageID) -> Language {
    _read {
      yield languages[l]!
    }
  }

  init(_ nonMachineRepresentation: AtomicLanguageSet<Symbol>) {
    var mergedGraph = SmallDFA<MergedDFAEdgeLabel>()

    for (id, language) in nonMachineRepresentation {
      let d = language.dfa()
      let mergedState = mergedGraph.insertGraph(d, mapLabel: { .normal($0) })
      mergedGraph.addEdge(
        from: mergedGraph.start, to: mergedState[d.start]!, via: .entryPoint(id))

      mergedGraph.accepting.formUnion(
        d.states.lazy.filter { d.isAccepting($0) }.map { mergedState[$0]! })
    }

    let m = mergedGraph.minimized()
    mergedDFA = m
    let baseGraph = m.graph.map {
      Dictionary(uniqueKeysWithValues: $0.lazy.compactMap { (k, v) in k.normal.map { ($0, v)} })
    }

    self.languages = .init(
      uniqueKeysWithValues: m.outgoingEdges(m.start).map {
        let states = m.reachableStates(from: $0.otherEnd)
        return (
          $0.label.entryPoint!,
          Language(
            start: $0.otherEnd,
            states: states,
            graph: baseGraph,
            accepting: Set(m.accepting.filter { states.contains($0) }))
        )
      })
  }

}

extension AtomicLanguageMachines: CustomStringConvertible {

  var description: String {

    let states = mergedDFA.states.map { s in
      return s == mergedDFA.start ? ""
        : (mergedDFA.isAccepting(s) ? "  \(s) [shape=doublecircle];\n" : "")
        + mergedDFA.outgoingEdges(s).map {
          "  \(s) -> \($0.otherEnd) [label=\"\($0.label.normal!)\"];\n"
        }.joined()
    }.joined()

    return """

      digraph "Atomic Languages" {
        node [shape=circle]; edge [len=1.5];

      \(
        languages.map {
          id, l in
          "  \"\(id)\" [shape=none]; \"\(id)\" -> \(l.start);\n"
        }.joined()
      )
      \(states)}
      """
  }
}
