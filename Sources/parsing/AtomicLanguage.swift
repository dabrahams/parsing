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

  typealias Tail = RegularExpression<Symbol>

  /// Component languages whose representations do not begin with
  /// atomic languages, i.e. that started out as (or have been reduced
  /// to) regular expressions over symbols.
  var resolvedComponents: Tail

  /// For each base symbol of an atomic language Σ at the head of a
  /// component of this language, the part of that component that
  /// follows Σ.
  var unresolvedComponents: [Symbol: Tail]

  /// The combined tails of any self-recursive components.
  var selfRecursiveTail: Tail

  /// One of a set of component languages whose union represents a complete atomic language.
  struct Component: Hashable {
    typealias Tail = RegularExpression<Symbol>

    /// Either the base of a leading atomic language component having
    /// the same stripped prefix as the full atomic language, or `nil`
    /// indicating that the any leading component is a terminal
    /// symbol.
    var leadingBase: Symbol?

    /// A regular expression representing the remainder of the language
    var tail: Tail
  }

  init<
    Components: Collection<Component>
  >(base: Symbol, sansPrefix strippedPrefix: Symbol, components: Components)
  {
    self.base = base
    self.strippedPrefix = strippedPrefix
    var c = Dictionary(grouping: components, by: \.leadingBase)
    resolvedComponents = .init(Set((c.removeValue(forKey: nil) ?? []).lazy.map(\.tail)))
    selfRecursiveTail = .init(Set((c.removeValue(forKey: base) ?? []).lazy.map(\.tail)))
    unresolvedComponents = Dictionary(
      uniqueKeysWithValues: c.lazy.map { (k, v) in
        (k!, v.lazy.map(\.tail).reduce(.null, |))} )
  }

  func allComponents() -> [Component] {
    let commonTail = selfRecursiveTail*

    let resolved = resolvedComponents == .null ? [] : [Component(leadingBase: nil, tail: resolvedComponents◦commonTail)]
    return resolved
      + unresolvedComponents.map { (base, tail) in .init(leadingBase: base, tail: tail◦commonTail) }
  }

  mutating func add(_ c: Component) {
    switch c.leadingBase {
      case self.base:
        selfRecursiveTail ∪= c.tail
      case nil:
        resolvedComponents ∪= c.tail
      case .some(let b):
        unresolvedComponents[b, default: .null] |= c.tail
    }
  }

  mutating func substitute(_ substitution: Self) {
    precondition(base != substitution.base)
    guard let replacedTail = unresolvedComponents.removeValue(forKey: substitution.base) else { return }
    for s in substitution.allComponents() {
      var s1 = s
      s1.tail = s1.tail◦replacedTail
      add(s)
    }
  }
}

extension AtomicLanguage.Component: Language {

  init(_ tail: Tail) {
    self.leadingBase = nil
    self.tail = tail
  }

  init(_ leadingBase: Symbol? = nil, _ tail: Tail) {
    self.leadingBase = leadingBase
    self.tail = tail
  }

  func union(_ other: Self) -> Self {
    precondition(leadingBase == other.leadingBase)
    return .init(leadingBase, tail ∪ other.tail)
  }

  func concatenated(to t: AtomicLanguage<Symbol>.Component) -> Self {
    precondition(t.leadingBase == nil)
    return .init(leadingBase, self.tail ◦ t.tail)
  }

}

typealias AtomicLanguageSet<Symbol: Hashable>
  = [AtomicLanguage<Symbol>.ID: RegularExpression<Symbol>]

extension AtomicLanguage.Component: CustomStringConvertible {

  var description: String {
    "\(leadingBase.map {"\($0)"} ?? "ɛ")⁽⎺⁾ ◦ \(tail.simplified())"
  }

}

extension AtomicLanguage: CustomStringConvertible {

  var description: String {
    """
      \(base)⁽\(strippedPrefix)⁾ = resolved: \(resolvedComponents), selfRecursive: \(selfRecursiveTail.simplified())
        unresolved: \(unresolvedComponents.map { "\($0)⁽\(strippedPrefix)⁾ ◦ \($1)" }.joined(separator: ", "))
        all: \(allComponents().map { "\($0)" }.joined(separator: ", "))

      """
    /*
    """
      \(base)⁽\(strippedPrefix)⁾ = \(allComponents().map { "\($0)" }.joined(separator: ", "))
      """
     */
  }

}

extension AtomicLanguage.ID: CustomStringConvertible {

  var description: String { "\(base)⁽\(strippedPrefix)⁾" }

}
