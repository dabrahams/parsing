struct LazyMap<Key: Hashable, Value: Hashable> {
  let defaultValue: Value
  var base: Dictionary<Key,Value>

  init(defaultValue: Value, _ base: Dictionary<Key,Value>) {
    self.defaultValue = defaultValue
    self.base = base
  }

  subscript(_ key: Key) -> Value {
    _read {
      yield base[key] ?? defaultValue
    }
    set {
      base[key] = newValue
    }
    _modify {
      let d = defaultValue
      yield &base[key, default: d]
    }
  }

}
