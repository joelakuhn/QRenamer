import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:isolate';
import 'dart:io' show Platform;
import 'package:path/path.dart' as Path;

typedef ReadQRFunc = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>, ffi.Pointer<Utf8>);

class QRReaderFFI {

  ReadQRFunc? _read_qr_ffi_func;

  static QRReaderFFI? _instance;

  static QRReaderFFI get instance {
    if (_instance == null) {
      _instance = QRReaderFFI();
    }
    return _instance!;
  }

  QRReaderFFI() {
    var libraryPath = '';
    if (Platform.isMacOS) {
      libraryPath = 'libqr_reader_ffi.dylib';
    }
    else if (Platform.isWindows) {
      var currentPath = Path.dirname(Platform.resolvedExecutable);
      libraryPath = Path.join(currentPath, 'qr_reader_ffi.dll');
    }

    var libqrReaderFfi = ffi.DynamicLibrary.open(libraryPath);

    _read_qr_ffi_func = libqrReaderFfi
      .lookup<ffi.NativeFunction<ReadQRFunc>>('read_qr_ffi')
      .asFunction();
  }

  static String read_qr_ffi(String path, int maxSize) {
    var utf8Path = path.toNativeUtf8();
    var utf8MaxSize = maxSize.toString().toNativeUtf8();
    var qrData = instance._read_qr_ffi_func!(utf8Path, utf8MaxSize);
    return qrData.toDartString();
  }

  Future<String> read_qr(String path, int maxSize) async {
    var receivePort = new ReceivePort();

    Isolate.spawn(read_qr_isolate, [ receivePort.sendPort, path, maxSize ]);
    var qrData = await receivePort.first as String;

    return qrData;
  }

  static void read_qr_isolate(List<dynamic> message) async {
    var sendPort = message[0] as SendPort;
    var path = message[1] as String;
    var maxSize = message[2] as int;
    var qrData = read_qr_ffi(path, maxSize);
    sendPort.send(qrData);
  }
}
