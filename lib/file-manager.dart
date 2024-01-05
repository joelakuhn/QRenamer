import 'event.dart';
import 'ui-file.dart';

class FileManager {
  static final FileManager instance = FileManager();
  Event changeEvent = new Event();

  List<UIFile> _files = [];
  List<UIFile> get files { return _files; }
  set files(newFiles) {
    _files = newFiles;
    changeEvent.emit();
  }

  void clear() {
    _files = [];
    changeEvent.emit();
  }

  bool get hasFiles { return _files.length > 0; }
}
