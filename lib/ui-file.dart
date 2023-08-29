import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;

import 'formatter.dart';
import 'string-brigade.dart';

class UIFile {
  late String path;
  late String _name;
  late String _fileNumber;
  late String _originalPath;
  late int _intFileNumber;
  late Formatter _formatter;

  StringBrigade _qr = StringBrigade();
  bool decoded = false;
  bool processed = false;
  TextEditingController controller = TextEditingController();

  UIFile(String path, Formatter formatter) {
    this._formatter = formatter;

    this.path = path;
    _originalPath = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);
  }

  void reset() {
    _qr = StringBrigade();
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0).toString() : "";
  }

  String get qr { return _qr.value; }
  set qr(String value) {
    if (value == "") {
      _qr.setEmpty();
    }
    else {
      _qr.setValue(value);
    }
    if (_qr.value != controller.text) {
      controller.text = value;
    }
  }

  String get name { return _name; }

  String get newPath {
    return _formatter.apply(this);
  }

  String get fileNumber { return _fileNumber; }

  int get intFileNumber { return _intFileNumber; }

  String get originalPath { return _originalPath; }
}
