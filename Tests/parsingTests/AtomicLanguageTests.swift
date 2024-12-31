import Testing
@testable import parsing

fileprivate typealias L = AtomicLanguage<Character>

@Test func terminal()  {

  let l0 = L(base: "x", sansPrefix: "x", components: [.init(leadingBase: nil, tail: .epsilon)])
  let c0 = l0.allComponents()
  #expect(c0 == [L.Component(leadingBase: nil, tail: .epsilon)])

  let l1 = L(base: "x", sansPrefix: "y", components: [])
  let c1 = l1.allComponents()
  #expect(c1 == [])
}

@Test func basic() throws {

  var l = try L(
    base: "X", sansPrefix: "a",
    components: [
      .init(leadingBase: "Y", tail: .init("a|b")),
      .init(leadingBase: "Z", tail: .init("Yc*")),
      .init(leadingBase: "X", tail: .init("d")),
      .init(leadingBase: "X", tail: .init("e")),
      .init(leadingBase: "Z", tail: .init("f")),
      .init(leadingBase: nil, tail: .init("ghi")),
      .init(leadingBase: nil, tail: .init("j|k|l"))]
  )

  typealias C = L.Component
  let c = l.allComponents().sorted { "\($0.tail)" < "\($1.tail)" }
  let x = try [
      C(leadingBase: "Y", tail: .init("(a|b)(d|e)*")),
      C(leadingBase: "Z", tail: .init("(Yc*|f)(d|e)*")),
      C(leadingBase: nil, tail: .init("(ghi|j|k|l)(d|e)*"))].sorted { "\($0.tail)" < "\($1.tail)" }

  #expect(c == x)

  let l1 = try L(
    base: "Y", sansPrefix: "a",
    components:[
      .init(leadingBase: "Y", tail: .init("m")),
      .init(leadingBase: "W", tail: .init("n"))
    ])

  l.substitute(l1)

  let c0 = l.allComponents().sorted { "\($0.tail)" < "\($1.tail)" }
  let x0 = try [
      C(leadingBase: "W", tail: .init("nm*(d|e)*")),
      C(leadingBase: "Z", tail: .init("(Yc*|f)(d|e)*")),
      C(leadingBase: nil, tail: .init("(ghi|j|k|l)(d|e)*"))].sorted { "\($0.tail)" < "\($1.tail)" }

  #expect(c0 == x0)

}

fileprivate typealias LSet = AtomicLanguageSet<Character>

extension LSet {

  func expectEquivalence(to x: Self) {
    #expect(Set(self.keys) == Set(x.keys))
    for (k, v) in self {
      if let v1 = x[k] {
        #expect(v.isFunctionallyEquivalent(to: v1), "\(v)")
      }
    }
  }

}

@Test func herman1() throws {
  try G(
    """
      S → ○
      S → S○
      S → S◁S▷
      """).reducedAtomicLanguages()
    .expectEquivalence(
      to: [
        .init(base: "S", strippedPrefix: "○"): R("(○|◁S▷)*"),
        .init(base: "◁", strippedPrefix: "◁"): .epsilon,
        .init(base: "○", strippedPrefix: "○"): .epsilon,
        .init(base: "▷", strippedPrefix: "▷"): .epsilon])
}

@Test func herman2() throws {
  try G(
    """
      S → ○
      S → S○
      S → S◁S▷
      S → ɛ
      """).reducedAtomicLanguages()
    .expectEquivalence(
      to: [
        .init(base: "S", strippedPrefix: "○"): R("(○|◁S?▷)*"),
        // The paper doesn't mention this component explicitly
        .init(base: "S", strippedPrefix: "◁"): R("S?▷(◁S?▷|○)*"),
        .init(base: "◁", strippedPrefix: "◁"): .epsilon,
        .init(base: "○", strippedPrefix: "○"): .epsilon,
        .init(base: "▷", strippedPrefix: "▷"): .epsilon])
}

@Test func hendriksERule() throws {
  try G(
    """
      S → ()
      S → a
      S → Sa
      S → SbSc
      """).reducedAtomicLanguages()
    .expectEquivalence(
      to: [
        .init(base: "S", strippedPrefix: "a"): R("(a|bc|bSc)∗"),
        .init(base: "S", strippedPrefix: "b"): R("(c|Sc)(a|bc|bSc)∗"),
        .init(base: "a", strippedPrefix: "a"): .epsilon,
        .init(base: "b", strippedPrefix: "b"): .epsilon,
        .init(base: "c", strippedPrefix: "c"): .epsilon])
}
