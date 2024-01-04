import 'dart:math' as Math;
import 'dart:io' as IO;

import 'package:qrenamer/file-manager.dart';

import 'qr-reader-ffi.dart';
import 'page.dart';
import 'ui-file.dart';

class Renamer {
  late PageState _state;
  int _concurrencyLevel = 1;
  int _renameIndex = 0;
  int _complete = 0;
  QRReaderFFI _qrReaderFfi = QRReaderFFI();
  final List<Function> _pctListeners = [];
  final List<Function> _completeListeners = [];
  final _fileManager = FileManager.instance;


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

  void addPctListener(Function listener) {
    _pctListeners.add(listener);
  }

  void addCompleteListener(Function listener) {
    _completeListeners.add(listener);
  }

  void _renameOne() async {
    if (!_state.isRunning) return;
    if (_renameIndex >= _fileManager.files.length) return;

    var file = _fileManager.files[_renameIndex++];

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
      _handleFileComplete();
    });
  }

  void _handleFileComplete() {
    _incrementComplete();
    _maybeStopRunning();
    _renameOne();
  }

  void _incrementComplete() {
    int newPctComplete = (++_complete / _fileManager.files.length * 100).round();
    _pctListeners.forEach((listener) => listener(newPctComplete));
  }

  void _maybeStopRunning() {
    if (_complete >= _fileManager.files.length) {
      _completeListeners.forEach((listener) => listener());
    }
  }
}