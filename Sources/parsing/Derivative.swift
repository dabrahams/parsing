import Graphs

typealias AStar = AStarAlgorithm

/*
enum Derivative<Symbol: Hashable> {
  case epsilon
  case nonEmpty(NonEmpty)

  struct Name: Hashable {
    let base: Symbol
    let prefix: Symbol
  }

  enum Head: Hashable {
    case derivative(Name)
    case plain(Symbol)

    var derivative: Name? {
      if case .derivative(let x) = self { return x }
      return nil
    }

    var plain: Symbol? {
      if case .plain(let x) = self { return x }
      return nil
    }
  }

  struct NonEmpty: Hashable, SemiLanguage {
    typealias Tail = RegularExpression<Symbol>

    var head: Head
    var tail: Tail

    func replacingHead(with newHead: Set<Self>) -> Set<Self> {
      var result: Set<Self> = []
      for var x in newHead {
        x.tail = x.tail ◦ self.tail
        result.insert(x)
      }
      return result
    }

    func concatenated(to tail: Tail) -> Self {
      var r = self
      r.tail = self.tail◦tail
      return r
    }
  }
}

extension Derivative: SemiLanguage {
  typealias Symbol = NonEmpty.Symbol

  func concatenated(to tail: Self) -> Self {

  }
}
 */
