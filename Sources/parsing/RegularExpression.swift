enum Quantifier: Character {
  case zeroOrMore = "*"
  case oneOrMore = "+"
  case optional = "?"
}

extension Quantifier: CustomStringConvertible {
  var description: String { String(rawValue) }
}

enum RegularExpression<Symbol> {
  case sequence([Self])
  case alternatives([Self])
  indirect case quantified(Self, Quantifier)
  case atom(Symbol)
}

extension RegularExpression: Sendable where Symbol: Sendable {}
extension RegularExpression: Hashable where Symbol: Hashable {}
extension RegularExpression: Equatable where Symbol: Equatable {}

extension RegularExpression: CustomStringConvertible {

  var description: String {
    if case .sequence(let x) = self, x.isEmpty { return "()" }
    return self.described(inSequenceOrQuantified: false)
  }

  private func described(inSequenceOrQuantified: Bool) -> String {
    let (l, r) = inSequenceOrQuantified ? ("(",")") : ("","")

    switch self {
    case .sequence(let s):
      return l + s.map { $0.described(inSequenceOrQuantified: true) }.joined() + r
    case .alternatives(let s):
      return l + s.map { $0.described(inSequenceOrQuantified: false) }.joined(separator: "|") + r
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
    var alternatives = try [Self(readingAlternativeFrom: &input)]
    while case .alternative = input.peek  {
      _ = input.next()
      try alternatives.append(Self(readingAlternativeFrom: &input))
    }
    self = alternatives.count == 1 ? alternatives[0] : .alternatives(alternatives)
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
        sequence.append(.quantified(sequence.popLast()!, q))
        _ = input.next()
      }
    }
    self = sequence.count == 1 ? sequence[0] : .sequence(sequence)
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
    case .alternatives(let s),
         .sequence(let s):
      return Set(s.lazy.flatMap { $0.symbols() })
    case .atom(let s):
      return Set([s])
    }
  }

  func map<T>(_ f: (Symbol)->T) -> RegularExpression<T> {
    typealias R = RegularExpression<T>

    switch self {
    case .quantified(let base, let q):
      return .quantified(base.map(f), q)
    case .alternatives(let a):
      return .alternatives(a.map { $0.map(f) })
    case .atom(let s):
      return .atom(f(s))
    case .sequence(let s):
      return .sequence(s.map { $0.map(f) })
    }
  }

  static var epsilon: Self { .sequence([]) }
}

extension RegularExpression: Language {

  func concatenated(to tail: Self) -> Self {
    // Don't create a sequence for concatenating epsilon
    if case .sequence(let x) = self, x.isEmpty { return tail }
    if case .sequence(let x) = tail, x.isEmpty { return self }

    if case .sequence(let h) = self {
      if case .sequence(let t) = tail {
        return .sequence(h + t)
      }
      return .sequence(h + CollectionOfOne(tail))
    }
    if case .sequence(let t) = tail {
      return .sequence(CollectionOfOne(self) + t)
    }
    return .sequence([self, tail])
  }

  func union(_ other: Self) -> Self {
    if case .alternatives(let h) = self {
      if case .alternatives(let t) = other {
        return .alternatives(h + t)
      }
      return .alternatives(h + CollectionOfOne(other))
    }
    if case .alternatives(let t) = other {
      return .alternatives(CollectionOfOne(self) + t)
    }
    return .alternatives([self, other])
  }
}
