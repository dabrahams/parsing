import Algorithms
infix operator ◦
infix operator ∪

protocol Language<Symbol> {
  associatedtype Symbol

  func concatenated(to tail: Self) -> Self
  func union(_ other: Self) -> Self
}

extension Language {
  static func ◦(l: Self, r: Self) -> Self { l.concatenated(to: r) }
  static func ∪(l: Self, r: Self) -> Self { l.concatenated(to: r) }
}

/*
extension Language where Self: Collection {
  static func ◦<Tail: Language<Symbol>>(l: Self, r: Tail) -> Product2Sequence<Self, Tail> {
    l.concatenated(to: r)
  }

  func concatenated<Tail: Language<Symbol>>(to tail: Tail) -> Product2Sequence<Self, Tail> {
    product(self, tail)
  }
}

extension Product2Sequence: Language where Element: Language {
  typealias Symbol = Element.Symbol

  func concatenated(to tail: Self) -> Self { Product2Sequence(self, tail)}
}
 */

extension Set: Language where Element: Language {

  typealias Symbol = Element.Symbol

  func concatenated(to tail: Self) -> Self {
    Set(product(self, tail).lazy.map { $0◦$1 })
  }

}
