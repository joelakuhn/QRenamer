import 'dart:ffi';

class StringBrigade {
  bool _ready = false;
  bool _isset = false;
  bool _isreal = false;
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
    if (_prev != null && _prev!._isset) {
      _value = _prev!.value;
      _isset = true;
    }
  }

  void setValue(String value) {
    _value = value;
    _ready = true;
    _isset = true;

    if (_next != null) {
      _next!.checkahead(value);
    }
  }

  bool checkahead(String value) {
    if (_isset) {
      return true;
    }
    else {
      if (_next == null || _next!.checkahead(value)) {
        _value = value;
        return true;
      }
      else {
        return false;
      }
    }
  }

  String get value {
    return _value;
  }
}