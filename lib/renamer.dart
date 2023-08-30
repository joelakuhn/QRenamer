import 'dart:math' as Math;
import 'dart:io' as IO;

import 'qr-reader-ffi.dart';
import 'page.dart';

class Renamer {
  late PageState _state;
  int _concurrencyLevel = 1;
  int _renameIndex = 0;
  int _complete = 0;
  QRReaderFFI _qrReaderFfi = QRReaderFFI();

  Renamer(PageState state) {
    _state = state;
    _concurrencyLevel = Math.max(1, (IO.Platform.numberOfProcessors / 3).floor());
  }

  void start() async {
    _renameIndex = 0;
    _complete = 0;

    for (var _ = 0; _ < _concurrencyLevel; _++) {
      _renameOne();
    }
  }

  void _renameOne() async {
    if (!_state.isRunning) return;
    if (_renameIndex >= _state.files.length) return;

    var file = _state.files[_renameIndex++];

    _qrReaderFfi.read_qr(file.path, 0)
    .then((qr) {
      if (!_state.isRunning) return;
      file.qr = qr;
    })
    .catchError((_e) {
      if (!_state.isRunning) return;
      file.qr = "";
    })
    .whenComplete(() {
      if (!_state.isRunning) return;
      file.decoded = true;
      _state.outsideSetState();
      _handleFileComplete();
    });
  }

  void _handleFileComplete() {
    _incrementComplete();
    _maybeStopRunning();
    _renameOne();
  }

  void _incrementComplete() {
    _state.pctComplete = (++_complete / _state.files.length * 100).round();
    _state.outsideSetState();
  }

  void _maybeStopRunning() {
    if (_complete >= _state.files.length) {
      _stopRunning();
    }
  }

  void _stopRunning() {
    if (_state.isRunning) {
      _state.isRunning = false;
      _state.outsideSetState();
    }
  }
}