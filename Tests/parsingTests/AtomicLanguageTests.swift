import Testing
@testable import parsing

fileprivate typealias L = AtomicLanguage<Character>

@Test func terminal()  {

  let l0 = L(base: "x", sansPrefix: "x", components: [.init(leadingBase: nil, tail: .epsilon)])
  let c0 = l0.allComponents()
  #expect(c0 == [L.Component(leadingBase: nil, tail: .epsilon)])

  let l1 = L(base: "x", sansPrefix: "y", components: [])
  let c1 = l1.allComponents()
  #expect(c1.isEmpty)
}

@Test func basic() throws {

  let l = try L(
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
      C(leadingBase: nil, tail: .init("ghi(d|e)*")),
      C(leadingBase: nil, tail: .init("(j|k|l)(d|e)*"))].sorted { "\($0.tail)" < "\($1.tail)" }

  #expect(c == x)
}
