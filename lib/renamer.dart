import 'dart:math' as Math;
import 'dart:io' as IO;

import 'file-manager.dart';
import 'qr-reader-ffi.dart';
import 'event.dart';

class Renamer {
  int _concurrencyLevel = 1;
  int _renameIndex = 0;
  int _complete = 0;
  QRReaderFFI _qrReaderFfi = QRReaderFFI();
  final _fileManager = FileManager.instance;
  bool _isRunning = false;
  final Event pctEvent = Event();
  final Event completeEvent = Event();

  bool get isRunning { return _isRunning; }

  Renamer() {
    _concurrencyLevel = Math.max(1, (IO.Platform.numberOfProcessors / 3).floor());
  }

  void start() async {
    _renameIndex = 0;
    _complete = 0;
    _isRunning = true;

    for (var _ = 0; _ < _concurrencyLevel; _++) {
      _renameOne();
    }
  }

  void stop() {
    _isRunning = false;
  }

  int get pctComplete {
    return (_complete / _fileManager.files.length * 100).round();
  }

  void _renameOne() async {
    if (!_isRunning) return;
    if (_renameIndex >= _fileManager.files.length) return;

    var file = _fileManager.files[_renameIndex++];

    _qrReaderFfi.read_qr(file.path, 0)
    .then((qr) {
      if (!_isRunning) return;
      file.qr = qr;
    })
    .catchError((_e) {
      if (!_isRunning) return;
      file.qr = "";
    })
    .whenComplete(() {
      if (!_isRunning) return;
      file.decoded = true;
      _handleFileComplete();
    });
  }

  void _handleFileComplete() {
    _incrementComplete();
    _maybeStopRunning();
    _renameOne();
  }

  void _incrementComplete() {
    _complete++;
    pctEvent.emit();
  }

  void _maybeStopRunning() {
    if (_complete >= _fileManager.files.length) {
      stop();
      completeEvent.emit();
    }
  }
}
