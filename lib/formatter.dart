import 'package:path/path.dart' as Path;

import 'ui-file.dart';

class Formatter {
  List<Function> _changeListeners = [];

  String _format = "";
  String get format { return _format; }
  set format(newFormat) {
    _format = newFormat;
    notifyChange();
  }

  void addChangeListener(Function listener) {
    _changeListeners.add(listener);
  }

  void notifyChange() {
    for (var listener in _changeListeners) {
      listener();
    }
  }

  String apply(UIFile file) {
    if (_format.indexOf("{qr}") < 0 && file.name.indexOf(file.qr) >= 0) return file.path;

    var ext = Path.extension(file.name);
    var newName = _format;
    newName = newName.replaceAll("{qr}", file.qr);
    newName = newName.replaceAll("{file-name}", Path.basenameWithoutExtension(file.name));
    newName = newName.replaceAll("{file-number}", file.fileNumber);
    if (!newName.toLowerCase().endsWith(ext.toLowerCase())) {
      newName += ext;
    }
    var newPath = Path.join(Path.dirname(file.path), newName);
    return newPath;
  }
}
