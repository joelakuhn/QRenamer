import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;

class UIFile {
  late String _path;
  late String _name;
  late String _newPath;
  late String _newName;
  late String _fileNumber;
  late int _intFileNumber;
  late String _qr;
  bool wasDryRun = false;
  bool decoded = false;
  bool processed = false;
  TextEditingController controller = TextEditingController();

  UIFile(String path) {
    this.path = path;
    this._newPath = "";
    this._newName = "";
    this.qr = "";
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0).toString() : "";
  }

  String get qr { return _qr; }
  set qr(value) {
    _qr = value;
    controller.text = value;
  }

  String get name { return _name; }
  String get path { return _path; }
  set path(path) {
    _path = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);
  }

  String get newName { return _newName; }
  String get newPath { return _newPath; }
  set newPath(path) {
    _newPath = path;
    _newName = Path.basename(path);
  }

  String get fileNumber { return _fileNumber; }

  int get intFileNumber { return _intFileNumber; }
}
