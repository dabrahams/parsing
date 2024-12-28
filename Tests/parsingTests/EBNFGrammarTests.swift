import Testing
@testable import parsing
typealias G = EBNFGrammar<Character>

struct BasicEBNFGrammarTokens<S: Sequence<Character>>: Sequence, IteratorProtocol {
  var base: Stream<S.Iterator>
  var expectation: Expectation = .lhs

  enum Expectation {
    case lhs, isDefinedAs, rhs
  }

  init(_ base: S) {
    var i = base.makeIterator()
    self.base = Stream(&i)
  }

  mutating func next() -> EBNFGrammar<Character>.Token? {
    while let c = base.peek, c.isWhitespace { _ = base.next() }
    guard let c = base.peek else { return nil }
    switch expectation {
    case .lhs:
      expectation = .isDefinedAs
      return .lhs(base.next()!)

    case .isDefinedAs:
      expectation = .rhs
      if "=→".contains(c) {
        _ = base.next()
        return .isDefinedAs
      }
      fallthrough
    case .rhs:
      expectation = .lhs
      var buffer: [Character] = []
      while var c = base.peek, c != "\n" {
        if c == ";" {
          _ = base.next()
          break
        }
        if c == "\\" {
          _ = base.next()
          c = base.next() ?? c
        }
        buffer.append(c)
        _ = base.next()
      }
      return .rhs(BasicRegularExpressionTokens(buffer))
    }
  }
}

extension EBNFGrammar where Symbol == Character {
  init(_ s: String) throws {
    var t = BasicEBNFGrammarTokens(s)
    self = try EBNFGrammar(readingFrom: &t)
  }
}

@Test func trivial() throws {
  let g = try G("A = xy")
  #expect(g.start == "A")
  #expect(g.nonTerminals == ["A"])
  #expect(g.terminals == ["x", "y"])
  #expect(g.nullables == [])
  #expect(g.symbols == g.terminals.union(g.nonTerminals))
}

@Test func oneNullable() throws {
  let g = try G("A = (Ax)?; A = y")
  #expect(g.start == "A")
  #expect(g.nonTerminals == ["A"])
  #expect(g.terminals == ["x", "y"])
  #expect(g.nullables == ["A"])
  #expect(g.symbols == g.terminals.union(g.nonTerminals))
}

@Test func trivialDerivative() throws {
  let g = try G(
    """
      Q →rs
      """)

  let d = g.derivatives(of: g.rules[0].rhs, by: "r")
  #expect(d.byBase.count == 1)
  let x = try AtomicLanguage<Character>.Component(R("s"))
  #expect(d.byBase[nil] == x, "\(d.byBase), \(x)")
  dump(d.byBase[nil]!.tail)
  dump(x.tail)
//  print(g.basicNonterminalAtomicLanguages())
}

@Test func derivatives() throws {
  let g = try G(
    """
      A →Ba
      A →a
      B →Ca
      B →b
      C →Aa
      C →c
      """)

  #expect(g.start == "A")
  #expect(g.nonTerminals == ["A", "B", "C"])
  #expect(g.terminals == ["a", "b", "c"])
  #expect(g.nullables == [])
  #expect(g.symbols == g.terminals.union(g.nonTerminals))

  /*
  print(g.basicNonterminalAtomicLanguages())
  for s in g.symbols {
    for t in g.terminals {
      print("=== \(G.Derivative(base: s, prefix: t)) ===")
      let rhses: [R] = g.terminals.contains(s) ? [.atom(s)] : g.rules.filter { $0.lhs == s }.map { $0.rhs }
      for r in rhses {
        print(g.derivatives(of: r, by: t))
      }
    }
  }
   */
}

@Test func derivatives2() throws {
  let g = try G(
    """
      A →Ba|a(ba)?
      B →Ca|b
      C →Aa|c(aa)*
      """)

  #expect(g.start == "A")
  #expect(g.nonTerminals == ["A", "B", "C"])
  #expect(g.terminals == ["a", "b", "c"])
  #expect(g.nullables == [])
  #expect(g.symbols == g.terminals.union(g.nonTerminals))
//  print(g.basicNonterminalAtomicLanguages())
/*
  for s in g.symbols {
    for t in g.terminals {
      print("=== \(G.Derivative(base: s, prefix: t)) ===")
      let rhses: [R] = g.terminals.contains(s) ? [.atom(s)] : g.rules.filter { $0.lhs == s }.map { $0.rhs }
      for r in rhses {
        print(g.derivatives(of: r, by: t))
      }
    }
    }

 */
}
