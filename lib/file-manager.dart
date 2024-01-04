import 'ui-file.dart';

class FileManager {
  static final FileManager instance = FileManager();

  List<Function> _changeListeners = [];

  void addChangeListener(Function listener) {
    _changeListeners.add(listener);
  }

  List<UIFile> _files = [];
  List<UIFile> get files { return _files; }
  set files(newFiles) {
    _files = newFiles;
    notifyChange();
  }

  void clear() {
    _files = [];
    notifyChange();
  }

  void notifyChange() {
    for (var listener in _changeListeners) {
      listener();
    }
  }

  bool get hasFiles { return _files.length > 0; }
}
