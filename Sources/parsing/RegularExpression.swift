postfix operator *
postfix operator +

enum Quantifier: Character {
  case zeroOrMore = "*"
  case oneOrMore = "+"
  case optional = "?"
}

extension Quantifier: CustomStringConvertible {
  var description: String { String(rawValue) }
}

enum RegularExpression<Symbol: Hashable> {
  case sequence([Self])
  case alternatives(Set<Self>)
  indirect case quantified(Self, Quantifier)
  case atom(Symbol)
}

extension RegularExpression: Sendable where Symbol: Sendable {}
extension RegularExpression: Hashable {}

/// Operators
///
/// Use these or combinator methods instead of using the cases directly.
extension RegularExpression {

  static postfix func*(x: Self) -> Self {
    switch x {
    case .null, .epsilon: return .epsilon
    default: return .quantified(x, .zeroOrMore)
    }
  }

  static postfix func+(x: Self) -> Self {
    switch x {
    case .null, .epsilon: return x
    default: return .quantified(x, .oneOrMore)
    }
  }

  static func|(l: Self, r: Self) -> Self {
    l ∪ r
  }

  static func|=(l: inout Self, r: Self) {
    l ∪= r
  }

  var optionally: Self {
    switch self {
    case .null, .epsilon: return .epsilon
    default: return .quantified(self, .optional)
    }
  }

}

extension RegularExpression {

  func quantified(by q: Quantifier) -> Self {
    switch q {
    case .zeroOrMore: return self*
    case .oneOrMore: return self+
    case .optional: return self.optionally
    }
  }

}

extension RegularExpression: CustomStringConvertible {

  var description: String {
    if case .sequence(let x) = self, x.isEmpty { return "()" }
    return self.described(inSequenceOrQuantified: false)
  }

  private func described(inSequenceOrQuantified: Bool) -> String {
    let (l, r) = inSequenceOrQuantified ? ("(",")") : ("","")

    switch self {
    case .epsilon: return "ɛ"
    case .null: return "∅"
    case .sequence(let s):
      return l + s.map { $0.described(inSequenceOrQuantified: true) }.joined() + r
    case .alternatives(let s):
      return l + s.map { $0.described(inSequenceOrQuantified: false) }.sorted().joined(separator: "|") + r
    case .quantified(let s, let q):
      return s.described(inSequenceOrQuantified: true) + "\(q)"
    case .atom(let s):
      return "\(s)"
    }
  }
}

/// An iterator with one element of lookahead.
public struct Stream<Generator: IteratorProtocol>: IteratorProtocol {
  public var peek: Generator.Element?

  var base: Generator

  public init(_ base: inout Generator) {
    peek = base.next()
    self.base = base
  }

  public mutating func next() -> Generator.Element? {
    defer { peek = base.next() }
    return peek
  }
}

extension RegularExpression {

  struct ParseError: Error {
    var message: String
  }

  enum Token {
    case leftParenthesis, rightParenthesis, alternative, quantifier(Quantifier), symbol(Symbol)
  }

  init<Tokens: Sequence<Token>>(readingFrom input_: inout Tokens) throws {
    var i = input_.makeIterator()
    var input = Stream(&i)
    try self.init(readingFrom: &input)
  }

  private init <Generator: IteratorProtocol<Token>>(readingFrom input: inout Stream<Generator>) throws {
    var alternatives = try Self(readingAlternativeFrom: &input)
    while case .alternative = input.peek  {
      _ = input.next()
      try alternatives ∪= Self(readingAlternativeFrom: &input)
    }
    self = alternatives
  }

  private init<Generator: IteratorProtocol<Token>>(readingAlternativeFrom input: inout Stream<Generator>) throws {
    var sequence: [Self] = []

    loop:
    while let c = input.peek {
      switch c {
      case .alternative, .rightParenthesis:
        break loop
      case .leftParenthesis:
        _ = input.next()
        try sequence.append(.init(readingFrom: &input))
        guard case .rightParenthesis = input.peek else {
          throw ParseError(message: "Missing right parenthesis")
        }
      case .quantifier(let q):
        throw ParseError(message: "Unexpected quantifier: \(q)")

      case .symbol(let s):
        sequence.append(.atom(s))
      }
      _ = input.next()
      if case .quantifier(let q) = input.peek {
        sequence.append(sequence.popLast()!.quantified(by: q))
        _ = input.next()
      }
    }
    self = sequence.reduce(into: .epsilon, ◦=)
  }
}

extension RegularExpression.Token: Equatable where Symbol: Equatable {}
extension RegularExpression.Token: Hashable where Symbol: Hashable {}

extension RegularExpression where Symbol: Hashable {

  func isNullable(nullableSymbols nulls: Set<Symbol>) -> Bool {
    switch self {
    case .quantified(let base, let q):
      if q == .zeroOrMore || q == .optional { return true }
      return base.isNullable(nullableSymbols: nulls)
    case .alternatives(let a):
      return a.contains { $0.isNullable(nullableSymbols: nulls) }
    case .atom(let s):
      return nulls.contains(s)
    case .sequence(let s):
      return s.allSatisfy { $0.isNullable(nullableSymbols: nulls) }
    }
  }

  func symbols() -> Set<Symbol> {
    switch self {
    case .quantified(let base, _):
      return base.symbols()
    case .alternatives(let s):
      return Set(s.lazy.flatMap { $0.symbols() })
    case .sequence(let s):
      return Set(s.lazy.flatMap { $0.symbols() })
    case .atom(let s):
      return Set([s])
    }
  }

  func map<T>(_ f: (Symbol)->T) -> RegularExpression<T> {
    switch self {
    case .quantified(let base, let q):
      return .quantified(base.map(f), q)
    case .alternatives(let a):
      return .alternatives(Set(a.map { $0.map(f) }))
    case .atom(let s):
      return .atom(f(s))
    case .sequence(let s):
      return .sequence(s.map { $0.map(f) })
    }
  }

  static var epsilon: Self { .sequence([]) }
  static var null: Self { .alternatives([]) }
}

extension RegularExpression: Language {

  func concatenated(to tail: Self) -> Self {
    // Don't create a sequence for concatenating epsilon
    switch (self, tail) {
    case (.null, _), (_, .null): return .null
    case (.epsilon, let t): return t
    case (let h, .epsilon): return h
    case (.sequence(let h), .sequence(let t)):
      return .sequence(h + t)
    case (.sequence(let h), let t):
      return .sequence(h + CollectionOfOne(t))
    case (let h, .sequence(let t)):
      return .sequence(CollectionOfOne(h) + t)
    case (let h, let t):
      return .sequence([h, t])
    }
  }

  func union(_ other: Self) -> Self {
    switch (self, other) {
    case (.null, let x), (let x, .null): return x
    case (.alternatives(let a), .alternatives(let b)):
      return .alternatives(a.union(b))
    case (.alternatives(let a), _):
      return .alternatives(a.union(CollectionOfOne(other)))
    case (_, .alternatives(let b)):
      return .alternatives(b.union(CollectionOfOne(self)))
    case (_, _):
      return .alternatives([self, other])
    }
  }
}

extension Collection where Element: SetAlgebra {

  func union() -> Element {
    self.reduce(into: Element()) { $0.formUnion($1) }
  }

}

extension Collection {

  func leadingSymbols<S>(nullables: Set<S>) -> Set<S> where Element == RegularExpression<S> {
    self.lazy.map { $0.leadingSymbols(nullables: nullables) }.union()
  }

}

extension RegularExpression where Symbol: Hashable {

  func leadingSymbols(nullables: Set<Symbol>) -> Set<Symbol> {
    switch self {
    case .quantified(let base, _):
      return base.leadingSymbols(nullables: nullables)
    case .alternatives(let a):
      return a.leadingSymbols(nullables: nullables)
    case .atom(let s):
      return [s]
    case .sequence(let s):
      var result = Set<Symbol>()
      for u in s {
        result.formUnion(u.leadingSymbols(nullables: nullables))
        if !u.isNullable(nullableSymbols: nullables) { break }
      }
      return result
    }
  }

}

extension RegularExpression: CustomDebugStringConvertible {

  var debugDescription: String {
    lispRepresentation(multiline: false)
//    "\n" + lispRepresentation(multiline: true)
  }

  func lispRepresentation(multiline: Bool, indent: Int = 0) -> String {

    let i = multiline ? String(repeatElement(" ", count: indent * 2)) : ""
    let br = multiline ? "\n  " + i : " "
    let close = multiline ? "\n\(i))" : ")"

    switch self {
    case .epsilon: return "ɛ"
    case .null: return "∅"
    case .quantified(let base, let q):
      return "(\(q.rawValue)\(br)\(base.lispRepresentation(multiline: multiline, indent: indent + 1))\(close)"
    case .alternatives(let a):
      return "(|\(br)\(String(a.map {$0.lispRepresentation(multiline: multiline, indent: indent + 1)}.sorted().joined(by: br)))\(close)"
    case .atom(let s):
      return "\(s)"
    case .sequence(let s):
      return "(seq\(br)\(String(s.map {$0.lispRepresentation(multiline: multiline, indent: indent + 1)}.joined(by: " ")))\(close)"
    }
  }

}

extension RegularExpression {

  init(_ x: Set<Self>) {
    self = x.count == 1 ? x.first! : x.reduce(into: .null, ∪=)
  }

  init<X: Collection<Self>>(_ x: X) {
    self = x.count == 1 ? x.first! : x.reduce(into: .epsilon, ◦=)
  }

}
