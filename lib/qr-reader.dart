import 'package:path/path.dart' as pathlib;
import 'dart:io' show Platform;
import 'dart:io' show Process;

class QRReader {

  String path_to_current_script() {
    final script = Platform.script;

    String pathToScript;
    if (script.isScheme('file')) {
      pathToScript = Platform.script.path;

      if (pathlib.basename(Platform.resolvedExecutable) == pathlib.basename(Platform.script.path)) {
        pathToScript = Platform.resolvedExecutable;
      }
    } else {
      /// when running in a unit test we can end up with a 'data' scheme
      if (script.isScheme('data')) {
        final start = script.path.indexOf('file:');
        final end = script.path.lastIndexOf('.dart');
        final fileUri = script.path.substring(start, end + 5);

        /// now parse the remaining uri to a path.
        pathToScript = Uri.parse(fileUri).toFilePath();
      }
    }

    return pathToScript;
  }

  static Future<String> read_qr(String path) async {
    var result = await Process.run("/Users/joel/builds/qr-reader/target/release/qr-reader", [ path ]);
    return result.stdout;
  }

}