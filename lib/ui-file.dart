import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:qrenamer/lazy-image.dart';

import 'formatter.dart';
import 'string-brigade.dart';

class UIFile {
  late String path;
  late String _name;
  late String _fileNumber;
  late String _originalPath;
  late int _intFileNumber;
  late Formatter _formatter;
  late LazyImage preview;
  late StringBrigade _stringBrigade;
  bool _decoded = false;
  bool _processed = false;

  TextEditingController controller = TextEditingController();
  List<Function> _changeListeners = [];

  bool get decoded { return _decoded; }
  set decoded(bool value) {
    _decoded = value;
    notifyChange();
  }

  bool get processed { return _processed; }
  set processed(bool value) {
    _processed = value;
    notifyChange();
  }

  UIFile(String path, Formatter formatter) {
    this.path = path;
    preview = new LazyImage(path);

    _originalPath = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);

    _formatter = formatter;
    _formatter.addChangeListener(notifyChange);

    _stringBrigade = StringBrigade();
    _stringBrigade.addChangeListener(notifyChange);
  }

  void addChangeListener(Function listener) {
    _changeListeners.add(listener);
  }

  void notifyChange() {
    for (var listener in _changeListeners) {
      listener();
    }
  }

  void reset() {
    _stringBrigade = StringBrigade();
    _stringBrigade.addChangeListener(notifyChange);
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0).toString() : "";
  }

  String get qr { return _stringBrigade.value; }
  set qr(String value) {
    if (value == "") {
      _stringBrigade.setEmpty();
    }
    else {
      _stringBrigade.setValue(value);
    }
    if (_stringBrigade.value != controller.text) {
      controller.text = value;
    }
  }

  String get name { return _name; }

  String get newPath {
    if (qr == "") {
      return path;
    }
    else {
      return _formatter.apply(this);
    }
  }

  String get fileNumber { return _fileNumber; }

  int get intFileNumber { return _intFileNumber; }

  String get originalPath { return _originalPath; }
}
