protocol NFA<Symbol>: FiniteAutomaton where EdgeLabel == EpsilonOr<Symbol>  {
  associatedtype Symbol: Hashable
}

protocol MutableNFA<Symbol>: NFA, MutableFiniteAutomaton {}

struct NFARecognizer<N: NFA> {
  var language: N

  typealias Configuration = Set<N.State>
  var configuration: Configuration

  init(recognizing language: N) {
    self.language = language
    configuration = language.epsilonClosure([language.start])
  }

  mutating func consume(_ c: N.Symbol) -> Bool {
    var next: Configuration = []

    for s in configuration {
      for e in language.outgoingEdges(s) where e.label == .some(c) {
        next.insert(e.otherEnd)
      }
    }
    if next.isEmpty { return false }
    configuration = language.epsilonClosure(next)
    return true
  }

  func currentAcceptingStates() -> Set<N.State> {
    return configuration.filter(language.isAccepting)
  }

}

extension NFA {

  typealias Recognizer = NFARecognizer<Self>

  /// Returns `true` iff `self` recognizes the string of symbols in `w`.
  func recognizes<Word: Collection<Symbol>>(_ w: Word) -> Bool {
    !acceptingStates(w).isEmpty
  }

  /// Returns the set of accepting states reached by recognizing the
  /// string of symbols in `w`, or `[]` if `w` is not recognized.
  func acceptingStates<Word: Collection<Symbol>>(_ w: Word) -> Set<State> {
    var r = Recognizer(recognizing: self)
    for c in w {
      if !r.consume(c) { return [] }
    }
    return r.currentAcceptingStates()
  }


  func epsilonClosure(_ s: Set<State>) -> Set<State> {
    var r: Set<State> = []
    var q: Set<State> = s

    while let v = q.popFirst() {
      if r.insert(v).inserted {
        for e in outgoingEdges(v) where e.label == .epsilon {
          q.insert(e.otherEnd)
        }
      }
    }
    return r
  }
}
