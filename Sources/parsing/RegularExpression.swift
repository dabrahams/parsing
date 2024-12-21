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
    self.described(inSequenceOrQuantified: false)
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
