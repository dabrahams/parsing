postfix operator ^

/// A tuple with conformances
struct Pair<First, Second> {
  var first: First
  var second: Second

  init(_ first: First, _ second: Second) {
    self.first = first
    self.second = second
  }

  init(_ x: (First, Second)) {
    self.first = x.0
    self.second = x.1
  }

  static postfix func ^(x: Self) -> (First, Second) { (x.first, x.second) }
}

extension Pair: Equatable where First: Equatable, Second: Equatable {}
extension Pair: Hashable where First: Hashable, Second: Hashable {}
extension Pair: Comparable where First: Comparable, Second: Comparable {
  static func < (l: Self, r: Self) -> Bool { l^ < r^ }
}

extension Pair: Codable where First: Codable, Second: Codable {}
