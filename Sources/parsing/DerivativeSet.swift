struct DerivativeSet<Symbol: Hashable>: Hashable {
  typealias Element = AtomicLanguage<Symbol>.Component

  var byBase: [Symbol?: Element] = [:]

  mutating func insert(_ e: Element) {
    byBase[e.leadingBase, default: .init(e.leadingBase, .null)].tail |= e.tail
  }

  init() {}
  init(_ e: Element) { self.insert(e) }

  var isEmpty: Bool { byBase.values.allSatisfy { $0.tail == .null } }
}

extension DerivativeSet: Language {

  func concatenated(to t: Self) -> Self {
    var result = self
    result.concatenate(t)
    return result
  }

  mutating func concatenate(_ t: Self) {
    if t.byBase.isEmpty {
      self = Self()
      return
    }
    precondition(t.byBase.count == 1)
    guard let t1 = t.byBase[nil]?.tail else { fatalError("illegal concatenation") }
    for i in byBase.indices {
      byBase.values[i].tail ◦= t1
    }
  }

  func union(_ other: Self) -> Self {
    var result = self
    result.byBase = byBase.merging(other.byBase) { l, r  in l.union(r) }
    return result
  }

  mutating func formUnion(_ other: Self) {
    byBase.merge(other.byBase) { l, r  in l.union(r) }
  }

}
