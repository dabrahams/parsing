import Testing
@testable import parsing
typealias R = RegularExpression<Character>

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
func description(_ r: R, expectedRepresentation: String) async throws {

}
