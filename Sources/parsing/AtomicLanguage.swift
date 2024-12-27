import Algorithms
import Collections


/// A representation of [s]⁽t⁾ (the derivative of the left-linear
/// closure of s by t).
struct AtomicLanguage<Symbol: Hashable> {

  /// The name of an atomic language.
  struct ID: Hashable {
    /// The symbol being left-linear closed over.
    let base: Symbol
    /// The terminal symbol stripped from the left linear closure of `base`.
    let strippedPrefix: Symbol
  }

  /// The symbol being left-linear closed over.
  let base: Symbol

  /// The terminal symbol stripped from the left linear closure of `base`.
  let strippedPrefix: Symbol

  typealias ComponentTail = RegularExpression<Symbol>

  /// Component languages whose representations do not begin with
  /// atomic languages, i.e. that started out as (or have been reduced
  /// to) regular expressions over symbols.
  var resolvedComponents: ComponentTail

  /// For each base symbol of an atomic language Σ at the head of a
  /// component of this language, the part of that component that
  /// follows Σ.
  var unresolvedComponents: [Symbol: Set<ComponentTail>]

  var selfRecursiveTails: ComponentTail

  /// One of a set of component languages whose union represents a complete atomic language.
  struct Component: Hashable {
    /// Either the base of a leading atomic language component having
    /// the same stripped prefix as the full atomic language, or `nil`
    /// indicating that the any leading component is a terminal
    /// symbol.
    var leadingBase: Symbol?

    /// A regular expression representing the remainder of the language
    var tail: ComponentTail
  }

  init<
    Components: Collection<Component>
  >(base: Symbol, sansPrefix strippedPrefix: Symbol, components: Components)
  {
    self.base = base
    self.strippedPrefix = strippedPrefix
    var c = Dictionary(grouping: components, by: \.leadingBase)
    resolvedComponents = .init(Set((c.removeValue(forKey: nil) ?? []).lazy.map(\.tail)))
    selfRecursiveTails = .init(Set((c.removeValue(forKey: base) ?? []).lazy.map(\.tail)))
    unresolvedComponents = Dictionary(uniqueKeysWithValues: c.lazy.map { (k, v) in (k!, Set(v.lazy.map(\.tail)))} )
  }

  func allComponents() -> [Component] {
    let commonTails = selfRecursiveTails*

    let resolved = resolvedComponents == .null ? [] : [Component(leadingBase: nil, tail: resolvedComponents◦commonTails)]
    return resolved
      + unresolvedComponents.map { (base, tails) in .init(leadingBase: base, tail: RegularExpression(tails)◦commonTails) }
  }

  mutating func add(_ c: Component) {
    switch c.leadingBase {
      case self.base:
        selfRecursiveTails = selfRecursiveTails.union(c.tail)
      case nil:
        resolvedComponents ∪= c.tail
      case .some(let b):
        unresolvedComponents[b, default: []].insert(c.tail)
    }
  }

  mutating func substitute(_ substitution: Self) {
    guard let replaced = unresolvedComponents.removeValue(forKey: substitution.base) else { return }
    for s in substitution.allComponents() {
      for oldTail in replaced {
        var s1 = s
        s1.tail = s1.tail◦oldTail
        add(s)
      }
    }
  }
}

extension RegularExpression where Symbol: Hashable {

  init(_ x: Set<Self>) {
    self = x.count == 1 ? x.first! : x.reduce(into: .null, ∪=)
  }

}

extension AtomicLanguage.Component: CustomStringConvertible {

  var description: String {
    "\((leadingBase.map {"\($0)"} ?? "ɛ", tail))"
  }

}
/*
import Graphs

struct SubstitutionSet<Symbol: Hashable> : Hashable {
  let lhs: Symbol
  let rhs: Set<Symbol>

  func substituting(_ other: Self) -> Self {
    .init(lhs: lhs, rhs: rhs.union(other.rhs).subtracting([lhs, other.lhs]))
  }
}

struct Search<Symbol: Hashable>: Hashable {
  var
}
 */

/*
extension AtomicLanguage {

}

/// One alternative in a set of regular languages describing
enum AtomicLanguageComponent<Symbol: Hashable> {
  case epsilon
  case nonEmpty(NonEmpty)

  struct Name: Hashable {
    let base: Symbol
    let prefix: Symbol
  }

  enum Head: Hashable {
    case derivative(Name)
    case plain(Symbol)

    var derivative: Name? {
      if case .derivative(let x) = self { return x }
      return nil
    }

    var plain: Symbol? {
      if case .plain(let x) = self { return x }
      return nil
    }
  }

  struct NonEmpty: Hashable, SemiLanguage {
    typealias Tail = RegularExpression<Symbol>

    var head: Head
    var tail: Tail

    func replacingHead(with newHead: Set<Self>) -> Set<Self> {
      var result: Set<Self> = []
      for var x in newHead {
        x.tail = x.tail ◦ self.tail
        result.insert(x)
      }
      return result
    }

    func concatenated(to tail: Tail) -> Self {
      var r = self
      r.tail = self.tail◦tail
      return r
    }
  }
}
*/
