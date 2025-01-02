import Algorithms

extension RegularExpression {

  // https://courses.grainger.illinois.edu/cs374/sp2019/notes/01_nfa_to_reg.pdf
  init<D: DFA<Symbol>>(_ d: D) {
    // We don't need a multigraph here.  We can preemptively union
    // edge labels instead.
    typealias G = LabeledBidirectionalMultiGraph<Self>
    var g = G()
    let vertex = g.insert(d, mapLabel: { .atom($0) })
    let initial = g.addVertex()
    let accept = g.addVertex()
    g.addEdge(from: initial, to: vertex[d.start]!, label: .epsilon)
    for s in d.states where d.isAccepting(s) {
      g.addEdge(from: vertex[s]!, to: accept, label: .epsilon)
    }

    var q = Array(vertex.values)
    func stepsThrough(_ v: G.Vertex) -> Int {
      g.predecessors[v]!.subtracting([v]).count * g.successors[v]!.subtracting([v]).count
    }
    while !q.isEmpty {
      q.sort { a, b in stepsThrough(a) > stepsThrough(b) }
      g.rip(q.popLast()!)
    }
    self = g.bundledLabel(from: initial, to: accept)
  }

}

extension LabeledBidirectionalMultiGraph {

  func bundledLabel<Symbol>(from s: Vertex, to t: Vertex) -> EdgeLabel
    where EdgeLabel == RegularExpression<Symbol>
  {
    labels[.init(source: s, target: t), default: []].reduce(.null, |)
  }

  // https://courses.grainger.illinois.edu/cs374/sp2019/notes/01_nfa_to_reg.pdf
  mutating func rip<Symbol>(_ v: Vertex)
    where EdgeLabel == RegularExpression<Symbol>
  {
    // Depends on .null* being .epsilon
    let center = bundledLabel(from: v, to: v)*

    for (p, s) in product(predecessors[v]!, successors[v]!) where s != v && p != v {
      let first = bundledLabel(from: p, to: v)
      let last = bundledLabel(from: v, to: s)
      // depends on x ◦ .epsilon being x
      let shortcut = first ◦ center ◦ last
      addEdge(from: p, to: s, label: shortcut)
    }
    remove(v)
  }

}
