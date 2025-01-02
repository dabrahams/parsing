extension EBNFGrammar {

  typealias Derivative = AtomicLanguage<Symbol>.Component
  typealias DerivativeID = AtomicLanguage<Symbol>.ID

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
      d = d◦DerivativeSet(Derivative(tail.nulling(nullables: nullables)))
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

  func atomicLanguages() -> AtomicLanguageSet<Symbol> {
    typealias Vertex = AtomicLanguage<Symbol>.ID
    typealias Time = Int

    var l = rawAtomicLanguages()

    let successors = { (u: Vertex) in
      l[u]!.unresolvedComponents.keys.lazy.map {
        Vertex(base: $0, strippedPrefix: u.strippedPrefix )
      }
    }

    var visiting: Set<Vertex> = []

    func resolve(_ u: Vertex) {

      func visit(_ u: Vertex) {
        visiting.insert(u)
        for v in successors(u) where !visiting.contains(v) {
          visit(v)
          l[u]!.substitute(l[v]!)
        }
        visiting.remove(u)
      }

      while !successors(u).isEmpty {
        visit(u)
      }
    }

    for t in terminals {
      for n in nonTerminals {
        resolve(.init(base: n, strippedPrefix: t))
      }
    }

    precondition(l.values.allSatisfy { $0.unresolvedComponents.isEmpty }, "\(l)")
    return l.compactMapValues {
      let c = $0.allComponents()
      precondition(c.count <= 1)
      return c.first?.tail
    }
  }

}
