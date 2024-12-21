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
