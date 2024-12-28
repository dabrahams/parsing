import Algorithms

struct EBNFGrammar<Symbol: Hashable> {
  struct Rule {
    typealias RHS = RegularExpression<Symbol>
    typealias LHS = Symbol

    var lhs: Symbol
    var rhs: RegularExpression<Symbol>
  }


  let start: Symbol
  let rules: [Rule]
  let terminals: Set<Symbol>
  let nonTerminals: Set<Symbol>
  let symbols: Set<Symbol>
  let rulesByLHS: [Symbol: [Rule]]

  public private(set) var nullables: Set<Symbol> = []

  init(start: Symbol, rules: [Rule]) {
    self.start = start
    self.rules = rules
    nonTerminals = Set(rules.lazy.map(\.lhs))
    terminals = Set(rules.lazy.flatMap { $0.rhs.symbols() } ).subtracting(nonTerminals)
    symbols = terminals.union(nonTerminals)
    rulesByLHS = Dictionary<Symbol, [Rule]>(grouping: rules, by: \.lhs)
    findNullables()
  }

}

extension EBNFGrammar {

  struct ParseError: Error {
    var message: String
  }

  enum Token {
    case rhs(any Sequence<Rule.RHS.Token>)
    case lhs(Rule.LHS)
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

      let rhs = try Rule.RHS(readingFrom: &r1)
      rules.append(Rule(lhs: lhs, rhs: rhs))
    }

    self.init(start: rules[0].lhs, rules: rules)
  }
}

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

extension EBNFGrammar {

  typealias Derivative = AtomicLanguage<Symbol>.Component
  typealias DerivativeID = AtomicLanguage<Symbol>.ID

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

  func atomicLanguageComponents(_ language: DerivativeID) -> DerivativeSet<Symbol>
  {
    if terminals.contains(language.base) {
      return language.base == language.strippedPrefix
        ? .init(Derivative(.epsilon)) : .init()
    }

    var result = DerivativeSet<Symbol>()
    for r in rulesByLHS[language.base, default: []] {
      result.formUnion(derivatives(of: r.rhs, by: language.strippedPrefix))
    }
    return result
  }

  func derivatives(
    of s: RegularExpression<Symbol>, by t: Symbol
  ) -> DerivativeSet<Symbol> {
    switch(s) {
    case .epsilon, .null: return .init()
    case .quantified(let r, let q):
      let d = derivatives(of: r, by: t)
      // “zero repeats” cases produce null, so if there's no more than one repeat, we're done.
      if q == .optional { return d }
      else {
        if d.isEmpty { return d } // don't bother lifting base if d is empty.
        return d ◦ DerivativeSet(Derivative(r*))
      }

    case .alternatives(let a):
      return a.reduce(into: DerivativeSet()) { $0.formUnion(derivatives(of: $1, by: t)) }

    case .atom(let x):
      if terminals.contains(x) {
        return DerivativeSet(Derivative(x == t ? .epsilon : .null))
      }
      return DerivativeSet(Derivative(x, .epsilon))

    case .sequence(var s):
      guard
        let first = s.first else { return .init() }

      var d = derivatives(of: first, by: t)
      if d.isEmpty || s.count == 1 { return d } // optimization
      s.removeFirst()
      let tail = RegularExpression(s)
      d = d◦DerivativeSet(Derivative(tail))
      if !first.isNullable(nullableSymbols: nullables) { return d }
      return d ∪ derivatives(of: tail, by: t)
    }
  }

  typealias Atomic = AtomicLanguage<Symbol>

  func rawAtomicLanguages() -> [DerivativeID: Atomic] {
    var r: [DerivativeID: Atomic] = [:]
    for s in symbols {
      for t in terminals {
        let id = DerivativeID(base: s, strippedPrefix: t)
        r[id] = AtomicLanguage(
          base: s, sansPrefix: t,
          components: atomicLanguageComponents(id).byBase.values)
      }
    }
    return r
  }

  func reducedAtomicLanguages() -> [DerivativeID: RegularExpression<Symbol>] {
    var l = rawAtomicLanguages()
    return [:]
  }
}

extension EBNFGrammar {

  func leadingRHSNonterminals(_ s: Symbol) -> Set<Symbol> {

    rulesByLHS[s, default: []].lazy.map {
      $0.rhs.leadingSymbols(nullables: nullables)
    }.union().intersection(nonTerminals)

  }

}
