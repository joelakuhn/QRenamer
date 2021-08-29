import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'dart:isolate';

import 'package:flutter/material.dart';

typedef ReadQRFunc = ffi.Pointer<Utf8> Function(ffi.Pointer<Utf8>);

class QRReaderFFI {

  static String read_qr_ffi(String path) {
    ffi.DynamicLibrary libqr_reader_ffi = ffi.DynamicLibrary.open('libqr_reader_ffi.dylib');
    ReadQRFunc read_qr_ffi_func = libqr_reader_ffi
      .lookup<ffi.NativeFunction<ReadQRFunc>>('read_qr_ffi')
      .asFunction();

    var utf8_path = path.toNativeUtf8();
    var qr_data = read_qr_ffi_func(utf8_path);
    return qr_data.toDartString();
  }

  Future<String> read_qr(String path) async {
    var receive_port = new ReceivePort();

    Isolate.spawn(read_qr_isolate, [ receive_port.sendPort, path ]);
    var qr_data = await receive_port.first as String;

    return qr_data;
  }

  static void read_qr_isolate(List<dynamic> message) async {
    var send_port = message[0] as SendPort;
    var path = message[1] as String;
    var qr_data = read_qr_ffi(path);
    send_port.send(qr_data);
  }
}
