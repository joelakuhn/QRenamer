import 'event.dart';

class StringBrigade {
  bool _isset = false;
  bool _isreal = false;
  String _value = "";
  StringBrigade? _prev;
  StringBrigade? _next;
  final Event changeEvent = Event();

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
    _isset = false;
    _isreal = false;

    if (_prev != null && _prev!._isset) {
      _value = _prev!.value;
      changeEvent.emit();
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
    changeEvent.emit();

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
        changeEvent.emit();
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
        changeEvent.emit();
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
