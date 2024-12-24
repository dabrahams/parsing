import Testing
@testable import parsing
typealias R = RegularExpression<Character>

extension R {

  init(_ s: String) throws {
    var t = BasicRegularExpressionTokens(s)
    self = try RegularExpression(readingFrom: &t)
  }

}

struct BasicRegularExpressionTokens<S: Sequence<Character>>: Sequence, IteratorProtocol {
  var base: S.Iterator

  init(_ base: S) {
    self.base = base.makeIterator()
  }

  mutating func next() -> RegularExpression<Character>.Token? {
    guard let x = base.next() else { return nil }
    switch x {
    case "(": return .leftParenthesis
    case ")": return .rightParenthesis
    case "|": return .alternative
    case "+": return .quantifier(.oneOrMore)
    case "*": return .quantifier(.zeroOrMore)
    case "?": return .quantifier(.optional)
    case "\\": return base.next().map { .symbol($0) }
    default: return .symbol(x)
    }
  }
}

@Test func check() {
  #expect(R.atom("x") == R.atom("x"))
}

@Test(arguments: [

        (R.atom("x"), "x"),
(R.quantified(.atom("x"), .oneOrMore), "x+"),
(R.sequence([.atom("x"), .atom("y")]), "xy"),
(R.alternatives([.atom("x"), .atom("y")]), "x|y"),
(R.quantified(R.alternatives([.atom("x"), .atom("y")]), .oneOrMore), "(x|y)+"),
(R.sequence([.atom("x"), .atom("y"), .alternatives([.atom("z"), .atom("w")])]), "xy(z|w)"),
(R.sequence([.atom("x"), .atom("y"), .sequence([.atom("z"), .atom("w")])]), "xy(zw)"),
(R.sequence([.atom("x"), .quantified(.atom("y"), .zeroOrMore), .atom("z")]), "xy*z"),
(R.sequence([.atom("x"), .quantified(.atom("y"), .optional), .atom("z")]), "xy?z")
      ])
func parsingAndUnparsing(_ r: R, expectedRepresentation: String) async throws {
  #expect("\(r)" == expectedRepresentation)
  var t = BasicRegularExpressionTokens(expectedRepresentation)
  let reconstructed = try RegularExpression(readingFrom: &t)
  #expect(reconstructed == r)
}
