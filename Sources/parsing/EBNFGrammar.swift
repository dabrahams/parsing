import Algorithms

struct EBNFGrammar<Symbol: Hashable> {
  struct Rule {
    var lhs: Symbol
    var rhs: RegularExpression<Symbol>
  }


  let start: Symbol
  let rules: [Rule]
  let terminals: Set<Symbol>
  let nonTerminals: Set<Symbol>
  let symbols: Set<Symbol>
  public private(set) var nullables: Set<Symbol> = []

  init(start: Symbol, rules: [Rule]) {
    self.start = start
    self.rules = rules
    nonTerminals = Set(rules.lazy.map(\.lhs))
    terminals = Set(rules.lazy.flatMap { $0.rhs.symbols() } ).subtracting(nonTerminals)
    symbols = terminals.union(nonTerminals)
    findNullables()
  }

}

extension EBNFGrammar {

  struct ParseError: Error {
    var message: String
  }

  enum Token {
    case rhs(any Sequence<RegularExpression<Symbol>.Token>)
    case lhs(Symbol)
    case isDefinedAs
  }

  init<Tokens: Sequence<Token>>(readingFrom input_: inout Tokens) throws {
    var i = input_.makeIterator()
    var input = Stream(&i)
    try self.init(readingFrom: &input)
  }

  private init <Generator: IteratorProtocol<Token>>(readingFrom input: inout Stream<Generator>) throws {
    var rules: [Rule] = []

    while let first = input.next() {
      guard case .lhs(let lhs) = first
      else { throw ParseError(message: "unexpected token \(first)") }
      guard let eq = input.next() else {
        throw ParseError(message: "expected is-defined-as token; got EOF")
      }
      guard case .isDefinedAs = eq else {
        throw ParseError(message: "expected is-defined-as token; got \(eq)")
      }
      guard let r = input.next() else {
        throw ParseError(message: "expected regular expression; got EOF")
      }
      guard case .rhs(var r1) = r else {
        throw ParseError(message: "expected is-defined-as token; got \(r)")
      }

      let rhs = try RegularExpression<Symbol>(readingFrom: &r1)
      rules.append(Rule(lhs: lhs, rhs: rhs))
    }

    self.init(start: rules[0].lhs, rules: rules)
  }
}

extension EBNFGrammar {

  mutating func findNullables() {
    while true {

      var foundNewNullable = false
      for r in rules where !nullables.contains(r.lhs) {
        if r.rhs.isNullable(nullableSymbols: nullables) {
          foundNewNullable = true
          nullables.insert(r.lhs)
        }
      }
      if !foundNewNullable { break }
    }
  }

  struct Derivative: Hashable {
    let base: Symbol
    let prefix: Symbol
  }

  enum DerivativeSymbol: Hashable {
    case derivative(Derivative)
    case plain(Symbol)
  }

  typealias DerivativeRHS = RegularExpression<DerivativeSymbol>

  func derivatives(of s: RegularExpression<Symbol>, by t: Symbol)
    -> Set<DerivativeRHS>
  {
    func lift(_ s: RegularExpression<Symbol>) -> Set<RegularExpression<DerivativeSymbol>> {
      Set([s.map { .plain($0) }])
    }

    switch(s) {
    case .quantified(let base, let q):
      let d = derivatives(of: base, by: t)
      // “zero repeats” cases produce nothing
      if q == .optional { return d }
      else {
        if d.isEmpty { return d } // don't bother lifting base if d is empty.
        return d◦lift(base)
      }

    case .alternatives(let a):
      return Set(a.lazy.flatMap { derivatives(of: $0, by: t) })

    case .atom(let x):
      if terminals.contains(x) { return x == t ? [.epsilon] : []}
      return [.atom(.derivative(.init(base: x, prefix: t)))]

    case .sequence(var s):
      guard
        let first = s.first else { return [] }

      var d = derivatives(of: first, by: t)
      if d.isEmpty || s.count == 1 { return d } // optimization
      s.removeFirst()
      let tail = RegularExpression.sequence(s)
      d = d◦lift(tail)
      if !first.isNullable(nullableSymbols: nullables) { return d }
      return d ∪ derivatives(of: tail, by: t)
    }
  }

  func basicNonterminalAtomicLanguages() -> [Derivative: Set<DerivativeRHS>] {
    let rulesByLHS = Dictionary<Symbol, [Rule]>(grouping: rules, by: \.lhs)

    var r: [Derivative: Set<DerivativeRHS>] = [:]
    for n in nonTerminals {
      for t in terminals {
        r[Derivative(base: n, prefix: t)] = Set(rulesByLHS[n, default: []].flatMap {derivatives(of: $0.rhs, by: t) })
      }
    }
    return r
  }

}

extension EBNFGrammar.Rule: CustomStringConvertible {

  var description: String {
    "\(lhs) = \(rhs)"
  }

}

extension EBNFGrammar.Derivative: CustomStringConvertible {

  var description: String {
    "[\(base)]⁽\(prefix)⁾"
  }

}

extension EBNFGrammar.DerivativeSymbol: CustomStringConvertible {

  var description: String {
    switch self {
    case .derivative(let s): return "\(s)"
    case .plain(let s): return "\(s)"
    }
  }

}
