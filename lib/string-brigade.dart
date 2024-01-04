class StringBrigade {
  bool _isset = false;
  bool _isreal = false;
  String _value = "";
  StringBrigade? _prev;
  StringBrigade? _next;
  List<Function> _changeListeners = [];

  static StringBrigade? last;

  void addChangeListener(Function callback) {
    _changeListeners.add(callback);
  }

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
    _isset = false;
    _isreal = false;

    if (_prev != null && _prev!._isset) {
      _value = _prev!.value;
      doCallbacks();
    }

    if (_prev != null) {
      checkbehind();
    }
    if (_next != null) {
      _next!.checkahead(value);
    }
  }

  void setValue(String value) {
    _value = value;
    _isset = true;
    _isreal = true;
    doCallbacks();

    if (_prev != null) {
      _prev!.checkbehind();
    }
    if (_next != null) {
      _next!.checkahead(value);
    }
  }

  String checkbehind() {
    if (_isreal) {
      return _value;
    }
    else if (_prev != null) {
      var maybeValue = _prev!.checkbehind();
      if (maybeValue != "") {
        _value = maybeValue;
        _isset = true;
        doCallbacks();
      }
      return maybeValue;
    }
    else {
      return "";
    }
  }

  bool checkahead(String value) {
    if (_isreal) {
      return true;
    }
    else if (!_isset) {
      return false;
    }
    else {
      if (_next == null || _next!.checkahead(value)) {
        _value = value;
        doCallbacks();
        return true;
      }
      else {
        return false;
      }
    }
  }

  void doCallbacks() {
    for (var listener in _changeListeners) {
      listener();
    }
  }

  String get value {
    return _value;
  }
}
