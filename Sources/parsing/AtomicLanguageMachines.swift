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

    self.languages = .init(
      uniqueKeysWithValues: m.outgoingEdges(m.start).map {
        let states = m.reachableStates(from: $0.otherEnd)
        return (
          $0.label.entryPoint!,
          Language(
            start: $0.otherEnd,
            states: states,
            graph: m.graph.map {
              Dictionary(uniqueKeysWithValues: $0.lazy.map { (k, v) in (k.normal!, v) })
            },
            accepting: Set(m.accepting.filter { states.contains($0) }))
        )
      }
    )
  }

}
