import Algorithms
infix operator ◦
infix operator ∪
infix operator ◦=
infix operator ∪=

protocol Language<Symbol> {
  associatedtype Symbol

  func concatenated(to tail: Self) -> Self
  func union(_ other: Self) -> Self

  mutating func concatenate(_ tail: Self)
  mutating func formUnion(_ other: Self)
}

extension Language {
  static func ◦(l: Self, r: Self) -> Self { l.concatenated(to: r) }
  static func ∪(l: Self, r: Self) -> Self { l.concatenated(to: r) }

  static func ◦=(l: inout Self, r: Self) { l.concatenate(r) }
  static func ∪=(l: inout Self, r: Self) { l.formUnion(r) }

  mutating func formUnion(_ other: Self) {
    self = self.union(other)
  }

  mutating func concatenate(_ tail: Self) {
    self = self.concatenated(to: tail)
  }
}

protocol LiftedLanguage: Language {
  associatedtype Unlifted: Language
  init(_ : Unlifted)
}

extension LiftedLanguage {

  func concatenated(to tail: Unlifted) -> Self {
    self.concatenated(to: Self(tail))
  }

  func union(_ other: Unlifted) -> Self {
    self.union(Self(other))
  }

  static func ◦(l: Self, r: Unlifted) -> Self { l.concatenated(to: r) }
  static func ∪(l: Unlifted, r: Self) -> Self { Self(l).concatenated(to: r) }

  static func ◦=(l: inout Self, r: Unlifted) { l.concatenate(r) }
  static func ∪=(l: inout Self, r: Unlifted) { l.formUnion(r) }

  mutating func formUnion(_ other: Unlifted) {
    self.formUnion(Self(other))
  }

  mutating func concatenate(_ tail: Unlifted) {
    self.concatenate(Self(tail))
  }

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

extension Set: Language, LiftedLanguage where Element: Language {

  typealias Unlifted = Element
  typealias Symbol = Element.Symbol

  init(_ base: Unlifted) { self = [base] }

  func concatenated(to tail: Self) -> Self {
    Set(product(self, tail).lazy.map { $0◦$1 })
  }

}

extension Optional: Language, LiftedLanguage where Wrapped: Language {

  typealias Unlifted = Wrapped
  typealias Symbol = Wrapped.Symbol

  func union(_ other: Self) -> Self {
    switch (self, other) {
    case (.some(let a), .some(let b)):
      return a ∪ b
    case (.some, _):
      return self
    case _:
      return other
    }
  }

  func concatenated(to tail: Self) -> Self {
    switch (self, tail) {
    case (.some(let l), .some(let r)):
      return l◦r
    case (.some, _):
      return self
    case _:
      return tail
    }
  }

}
