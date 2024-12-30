struct LabeledBidirectionalMultiGraph<EdgeLabel: Hashable> {
  typealias Vertex = Int

  struct EdgeEndpoints: Hashable {
    var source, target: Vertex
  }

  struct Edge: Hashable {
    var endpoints: EdgeEndpoints
    var label: EdgeLabel
  }

  typealias Successors = Set<Vertex>
  typealias Predecessors = Set<Vertex>

  var successors: [Vertex: Successors] = [:]
  var predecessors: [Vertex: Predecessors] = [:]
  var labels: [EdgeEndpoints: Set<EdgeLabel>] = [:]
  var nextVertex = 0

  var vertices: some Collection<Vertex> { successors.keys }

  func outgoingEdges(_ s: Vertex) -> some Collection<Edge> {
    successors[s]!.lazy.flatMap {
      let e = EdgeEndpoints(source: s, target: $0)
      return labels[e, default: []].lazy.map { Edge(endpoints: e, label: $0) }
    }
  }

  func incomingEdges(_ s: Vertex) -> some Collection<Edge> {
    predecessors[s]!.lazy.flatMap {
      let e = EdgeEndpoints(source: $0, target: s)
      return labels[e, default: []].lazy.map { Edge(endpoints: e, label: $0) }
    }
  }

  mutating func addVertex() -> Vertex {
    defer { nextVertex += 1 }
    successors[nextVertex] = []
    predecessors[nextVertex] = []
    return nextVertex
  }

  mutating func addEdge(from source: Vertex, to target: Vertex, label l: EdgeLabel) {
    successors[source]!.insert(target)
    predecessors[target]!.insert(source)
    labels[EdgeEndpoints(source: source, target: target), default:[]].insert(l)
  }

  mutating func remove(_ e: Edge) {
    let p = e.endpoints
    labels[p, default: []].remove(e.label)
    if labels[p, default: []].isEmpty {
      successors[p.source]!.remove(p.target)
      predecessors[p.target]!.remove(p.source)
    }
  }

  mutating func remove(_ v: Vertex) {
    for e in outgoingEdges(v) { remove(e) }
    for e in incomingEdges(v) { remove(e) }
    for p in predecessors[v, default: []] {
      successors[p]!.remove(v)
    }
    for s in successors[v, default: []] {
      predecessors[s]!.remove(v)
    }
    predecessors[v] = nil
    successors[v] = nil
  }
}

extension LabeledBidirectionalMultiGraph {

  mutating func insert<D: DFA>(_ d: D, mapLabel: (D.EdgeLabel)->EdgeLabel) -> [D.State: Vertex] {
    var vertex: [D.State: Vertex] = [:]

    for s in d.states {
      vertex[s] = addVertex()
    }

    for s in d.states {
      for e in d.outgoingEdges(s) {
        addEdge(from: vertex[s]!, to: vertex[e.otherEnd]!, label: mapLabel(e.label))
      }
    }

    return vertex
  }

}
