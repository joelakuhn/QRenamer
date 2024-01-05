import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;

import 'formatter.dart';
import 'string-brigade.dart';
import 'event.dart';

class UIFile {
  late String path;
  late String _name;
  late String _fileNumber;
  late String _originalPath;
  late int _intFileNumber;
  late Formatter _formatter;
  late StringBrigade _stringBrigade;
  bool _decoded = false;
  bool _processed = false;
  Event onChange = Event();

  TextEditingController controller = TextEditingController();

  bool get decoded { return _decoded; }
  set decoded(bool value) {
    _decoded = value;
    onChange.emit();
  }

  bool get processed { return _processed; }
  set processed(bool value) {
    _processed = value;
    onChange.emit();
  }

  UIFile(String path, Formatter formatter) {
    this.path = path;

    _originalPath = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);

    _formatter = formatter;
    _formatter.changeEvent.bind(this, onChange.emit);

    _stringBrigade = StringBrigade();
    _stringBrigade.changeEvent.bind(this, onChange.emit);
  }

  void reset() {
    _stringBrigade = StringBrigade();
    _stringBrigade.changeEvent.bind(this, onChange.emit);
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
