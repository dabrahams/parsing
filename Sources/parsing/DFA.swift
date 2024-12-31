protocol DFA<Symbol>: Equatable, FiniteAutomaton where EdgeLabel == Symbol {
  associatedtype Symbol: Hashable
  func successor(of s: State, via label: EdgeLabel) -> Optional<State>
}

extension DFA {

  /// Returns `true` iff `self` recognizes the string of symbols in `w`.
  func recognizes<Word: Collection<Symbol>>(_ w: Word) -> Bool {
    acceptingState(w) != nil
  }

  /// Returns the accepting state reached by recognizing the
  /// string of symbols in `w`, or `nil` if `w` is not recognized.
  func acceptingState<Word: Collection<Symbol>>(_ w: Word) -> Optional<State> {

    var current = start
    for c in w {
      guard let next = successor(of: current, via: c) else { return nil }
      current = next
    }
    return isAccepting(current) ? current : nil
  }

}

extension DFA {

  static func == (l: Self, r: Self) -> Bool {
    l.isEquivalent(to: r)
  }

  func isEquivalent<D: DFA<Symbol>>(to d: D) -> Bool {
    self.minimized().isStructurallyEquivalent(to: d.minimized())
  }

  func isStructurallyEquivalent<D: DFA<Symbol>>(to d: D) -> Bool {
    if states.count != d.states.count { return false }

    var dState: [State: D.State] = [start: d.start]
    var q = [start]

    while let v = q.popLast() {
      let vd = dState[v]!
      if isAccepting(v) != d.isAccepting(vd) { return false }
      let outEdges = outgoingEdges(v)
      if outEdges.count != d.outgoingEdges(vd).count { return false }

      for e in outEdges {
        let t = e.otherEnd
        let sd = d.successor(of: vd, via: e.label)
        if sd == nil { return false }
        if let td = dState[t] {
          if td != sd { return false }
        }
        else {
          dState[t] = sd
          q.append(t)
        }
      }
    }
    return true
  }

}

protocol MutableDFA<Symbol>: DFA, MutableFiniteAutomaton {}

extension DFA where EdgeLabel: Comparable {

  func hash(into h: inout Hasher) {
    self.minimized().hashMinimized(into: &h)
  }

  fileprivate func hashMinimized(into h: inout Hasher) {
    var visited: Set<State> = []
    var q: [State] = [start]
    while let s = q.popLast() {
      if !visited.insert(s).inserted { continue }
      if isAccepting(s) { true.hash(into: &h) }

      for e in outgoingEdges(s).sorted(by: { $0.label < $1.label }) {
        e.label.hash(into: &h)
        q.append(e.otherEnd)
      }
    }
  }

}
