class StringBrigade {
  bool _ready = false;
  bool _isset = false;
  String _value = "";
  StringBrigade? _prev;
  StringBrigade? _next;

  static StringBrigade? last;

  static reset() {
    StringBrigade.last = null;
  }

  StringBrigade() {
    if (StringBrigade.last != null) {
      StringBrigade.last!._next = this;
    }
    this._prev = StringBrigade.last;
    StringBrigade.last = this;
  }

  void setEmpty() {
    _ready = true;
  }

  void setValue(String value) {
    _value = value;
    _ready = true;
    _isset = true;
  }

  String get value {
    if (_ready) {
      if (_isset) {
        return _value;
      }
      else if (_prev != null) {
        return _prev!.value;
      }
    }
    return "";
  }

  String get immediateValue {
    return _value;
  }
}