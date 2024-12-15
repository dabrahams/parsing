enum EpsilonOr<T> {
  case some(T), epsilon

  var symbol: T {
    if case .some(let x) = self { return x }
    fatalError("No symbol; this is an epsilon")
  }
}

extension EpsilonOr: Equatable where T: Equatable {
  static func == (me: Self, other: T) -> Bool {
    if case .some(let x) = me { return x == other }
    return false
  }

  static func == (other: T, me: Self) -> Bool {
    if case .some(let x) = me { return x == other }
    return false
  }
}

extension EpsilonOr: Hashable where T: Hashable {}
extension EpsilonOr: Comparable where T: Comparable {}
extension EpsilonOr: Codable where T: Codable {}

extension EpsilonOr: CustomStringConvertible {
  var description: String {
    if case let .some(s) = self { "\(s)" } else {"ɛ" }
  }
}
