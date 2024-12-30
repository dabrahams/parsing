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
    case "ɛ": return .epsilon
    case "ø": return .null
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

@Test(
  arguments: [
    (R.atom("x"), "x"),
    (R.atom("x").quantified(by: .oneOrMore), "x+"),
    (R.atom("x")+, "x+"),
    (R.atom("x") ◦ R.atom("y"), "xy"),
    (R.atom("x") ∪ R.atom("y"), "x|y"),
    ((R.atom("x") ∪ R.atom("y"))+, "(x|y)+"),
    (R.atom("x") ◦ R.atom("y") ◦ (R.atom("z") ∪ R.atom("w")), "xy(w|z)"),
    (R.atom("x") ◦ R.atom("y") ◦ (R.atom("z") ◦  R.atom("w")), "xyzw"),
    (R.atom("x") ◦ R.atom("y")* ◦ R.atom("z"), "xy*z"),
    (R.atom("x") ◦ R.atom("y").optionally ◦ R.atom("z"), "xy?z")]
)
func parsingAndUnparsing(_ r: R, expectedRepresentation: String) async throws {
  #expect("\(r)" == expectedRepresentation)
  var t = BasicRegularExpressionTokens(expectedRepresentation)
  let reconstructed = try RegularExpression(readingFrom: &t)
  #expect(reconstructed == r)
}

@Test func simplification() throws {
  // Notes: smart regex construction is skewing these results a bit.
  let r = try R("(a|b)a*")
  let r1 = r.simplified()
  #expect(r == r1)
}
