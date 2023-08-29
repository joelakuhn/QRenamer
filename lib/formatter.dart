import 'package:path/path.dart' as Path;

import 'ui-file.dart';

class Formatter {
  String format = "";

  String apply(UIFile file) {
    if (format.indexOf("{qr}") < 0 && file.name.indexOf(file.qr) >= 0) return file.path;

    var ext = Path.extension(file.name);
    var newName = format;
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