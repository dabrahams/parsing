fileprivate func compare<T: Comparable, U>(_ x: T, _ y: U) -> Bool {
  return x < (y as! T)
}

extension Collection {

  func sortedIfPossible() -> [Element] {
    if isEmpty { return []}

    if Element.self as Any.Type is any Comparable.Type {
      return self.sorted {
        let l = $0 as! any Comparable
        return compare(l, $1)
      }
    }

    if self.first! as Any is (any Comparable, any Comparable) {
      return self.sorted {
        let l = $0 as! (any Comparable, any Comparable)
        let r = $1 as! (any Comparable, any Comparable)
        return compare(l.0, r.0) || !compare(r.0, l.0) && compare(l.1, r.1)
      }
    }

    if self.first! as Any is (any Comparable, Any) {
      return self.sorted {
        let l = $0 as! (any Comparable, Any)
        let r = $1 as! (Any, Any)
        return compare(l.0, r.0)
      }
    }

    return Array(self)
  }

}
