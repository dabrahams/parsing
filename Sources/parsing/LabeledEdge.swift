/// A graph edge for an adjacency list
struct LabeledAdjacencyEdge<Label, VertexID> {
  var label: Label
  var otherEnd: VertexID

  init(label: Label, _ otherEnd: VertexID) {
    self.label = label
    self.otherEnd = otherEnd
  }
}

extension LabeledAdjacencyEdge: Equatable where Label: Equatable, VertexID: Equatable {}
extension LabeledAdjacencyEdge: Hashable where Label: Hashable, VertexID: Hashable {}
extension LabeledAdjacencyEdge: Comparable where Label: Comparable, VertexID: Comparable {
  static func < (l: Self, r: Self) -> Bool { (l.label, l.otherEnd) < (r.label, r.otherEnd) }
}

extension LabeledAdjacencyEdge: Codable where Label: Codable, VertexID: Codable {}

extension LabeledAdjacencyEdge: CustomStringConvertible {
  var description: String {
    "\(otherEnd) via \(label)"
  }
}
