import 'package:path/path.dart' as Path;

class UIFile {
  String _path;
  String _name;
  String _newPath;
  String _newName;
  String _fileNumber;
  int _intFileNumber;
  String qr;
  bool wasDryRun = false;
  bool processed = false;

  UIFile(String path) {
    this.path = path;
    this._newPath = "";
    this._newName = "";
    this.qr = "";
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0) : "";
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
