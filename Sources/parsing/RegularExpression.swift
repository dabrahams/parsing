import Algorithms

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
    case .null, .epsilon: .epsilon
    case .quantified(let y, _): y*
    case .sequence(let y) where y.count == 1: y.first!*
    case .alternatives(let y) where y.count == 1: y.first!*
    default: .quantified(x, .zeroOrMore)
    }
  }

  static postfix func+(x: Self) -> Self {
    switch x {
    case .null, .epsilon: x
    case .quantified(_, .oneOrMore): x
    case _ where x.isNullable(): x*
    case .sequence(let y) where y.count == 1: y.first!+
    case .alternatives(let y) where y.count == 1: y.first!+
    default: .quantified(x, .oneOrMore)
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
    case .null, .epsilon: .epsilon
    case _ where self.isNullable(): self
    case .sequence(let y) where y.count == 1: y.first!.optionally
    case .alternatives(let y) where y.count == 1: y.first!.optionally
    case .quantified(let y, let q):
      .quantified(y, q == .optional ? q : .zeroOrMore)
    default: .quantified(self, .optional)
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
    case leftParenthesis, rightParenthesis, alternative, quantifier(Quantifier), symbol(Symbol), epsilon, null
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
    var nulled = false
    loop:
    while let c = input.peek {
      switch c {
      case .epsilon:
        sequence.append(.epsilon)
      case .null:
        nulled = true
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
    if nulled { self = .null }
    else { self.init(sequence) }
  }
}

extension RegularExpression.Token: Hashable {}

extension RegularExpression {

  func isNullable(nullableSymbols nulls: Set<Symbol> = []) -> Bool {
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

  /*
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
   */
  static var epsilon: Self { .sequence([]) }
  static var null: Self { .alternatives([]) }
}

extension RegularExpression: Language {

  func concatenated(to tail: Self) -> Self {
    switch (self, tail) {
    case (.null, _), (_, .null): .null
    // Don't create a sequence for concatenating epsilon
    case (.epsilon, let x), (let x, .epsilon): x
    case (.quantified(let x, .zeroOrMore), let y) where x == y,
         (let y, .quantified(let x, .zeroOrMore)) where x == y:
      .quantified(y, .oneOrMore)
    case (.sequence(let h), .sequence(let t)):
      .sequence(h + t)
    case (.sequence(let h), let t):
      .sequence(h + CollectionOfOne(t))
    case (let h, .sequence(let t)):
      .sequence(CollectionOfOne(h) + t)
    case (let h, let t):
      .sequence([h, t])
    }
  }

  func union(_ other: Self) -> Self {
    switch (self, other) {
    case (.null, let x), (let x, .null): x
    case (.epsilon, let x), (let x, .epsilon): x.optionally
    case (.alternatives(let a), .alternatives(let b)):
      .alternatives(a.union(b))
    case (.alternatives(let a), _):
      .alternatives(a.union(CollectionOfOne(other)))
    case (_, .alternatives(let b)):
      .alternatives(b.union(CollectionOfOne(self)))
    case (_, _):
      .alternatives([self, other])
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

extension RegularExpression {

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

  func nulling(nullables n: Set<Symbol>) -> Self {
    switch self {
    case .quantified(let base, let q):
      .quantified(base.nulling(nullables: n), q)
    case .alternatives(let a):
      a.lazy.map { $0.nulling(nullables: n) }.reduce(into: .null, |=)
    case .atom(let s):
      n.contains(s) ? self.optionally : self
    case .sequence(let s):
      s.first?.nulling(nullables: n)
        .concatenated(to: .sequence(Array(s[1...])).nulling(nullables: n))
        ?? self
    }
  }

}

extension RegularExpression {

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

extension RegularExpression {

  func nfa() -> SimpleNFA<Symbol> {
    var m = SimpleNFA<Symbol>()
    let end = self.build(into: &m, at: m.start)
    m.accepting.insert(end)
    return m
  }

  func dfa() -> SmallDFA<Symbol> {
    SmallDFA(EquivalentDFA<SimpleNFA<Symbol>>(nfa()))
  }

  func minimizedDFA() -> SmallDFA<Symbol> {
    SmallDFA(MinimizedDFA(dfa()))
  }

  func build<Machine: MutableNFA>(into machine: inout Machine, at start: Machine.State) -> Machine.State
    where Machine.Symbol == Symbol
  {
    let end = machine.addState()
    switch self {
    case .atom(let x): machine.addEdge(from: start, to: end, via: .some(x))

    case .alternatives(let a):
      for x in a {
        let s = machine.addState()
        machine.addEdge(from: start, to: s, via: .epsilon)
        let e = x.build(into: &machine, at: s)
        machine.addEdge(from: e, to: end, via: .epsilon)
      }

    case .sequence(let a):
      var s = start
      for x in a {
        s = x.build(into: &machine, at: s)
      }
      machine.addEdge(from: s, to: end, via: .epsilon)

    case .quantified(let x, let q):
      let e = x.build(into: &machine, at: start)
      machine.addEdge(from: e, to: end, via: .epsilon)

      if q != .oneOrMore {
        machine.addEdge(from: start, to: e, via: .epsilon)
      }
      if q != .optional {
        machine.addEdge(from: e, to: start, via: .epsilon)
      }
    }

    return end
  }
}

extension RegularExpression {

  func simplified() -> Self {
    let selfText = self.description
    // This could be a lot better but it's a start.  It's
    // nondeterministic across runs due to hash randomization.
    let candidate = Self(minimizedDFA())
    return candidate.description.count < selfText.count ? candidate : self
  }

}

extension RegularExpression {

  func isFunctionallyEquivalent(to r: Self) -> Bool {
    self.minimizedDFA() == r.minimizedDFA()
  }

}

