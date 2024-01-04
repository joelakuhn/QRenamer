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

  StringBrigade stringBrigade = StringBrigade();
  bool decoded = false;
  bool processed = false;
  TextEditingController controller = TextEditingController();

  UIFile(String path, Formatter formatter) {
    this._formatter = formatter;

    this.path = path;
    preview = new LazyImage(path);

    _originalPath = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);
  }

  void reset() {
    stringBrigade = StringBrigade();
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0).toString() : "";
  }

  String get qr { return stringBrigade.value; }
  set qr(String value) {
    if (value == "") {
      stringBrigade.setEmpty();
    }
    else {
      stringBrigade.setValue(value);
    }
    if (stringBrigade.value != controller.text) {
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
