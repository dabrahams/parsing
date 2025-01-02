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

}

extension EBNFGrammar {

  func leadingRHSNonterminals(_ s: Symbol) -> Set<Symbol> {

    rulesByLHS[s, default: []].lazy.map {
      $0.rhs.leadingSymbols(nullables: nullables)
    }.union().intersection(nonTerminals)

  }

}
