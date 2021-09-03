import 'dart:math' as Math;
import 'dart:io' as IO;

import 'package:path/path.dart' as Path;

import 'qr-reader-ffi.dart';
import 'page.dart';

class Renamer {
  PageState _state;
  String _format = "";
  int _concurrencyLevel = 1;
  int _renameIndex = 0;
  int _maxSize = 0;
  int _complete = 0;
  int _lastUpdated = 0;
  QRReaderFFI _qrReaderFfi = QRReaderFFI();

  Renamer(PageState state) {
    _state = state;
    _concurrencyLevel = Math.max(1, (IO.Platform.numberOfProcessors / 4).floor());
  }

  void start(format, maximizeAccuracy) async {
    _format = format;
    _renameIndex = 0;
    _maxSize = maximizeAccuracy ? 0 : 1500;
    _complete = 0;
    _lastUpdated = 0;

    for (var _ = 0; _ < _concurrencyLevel; _++) {
      _renameOne();
    }
  }

  void _renameOne() async {
    if (!_state.isRunning) return;
    if (_renameIndex >= _state.files.length) return;

    var file = _state.files[_renameIndex++];
  
    if (file.processed && !file.wasDryRun) {
      _handleFileComplete();
    }
    else {
      _qrReaderFfi.read_qr(file.path, _maxSize)
      .then((qr) {
        if (!_state.isRunning) return;
        if (qr.length > 0) file.qr = qr;

        _maybeRename();
      })
      .whenComplete(() {
        file.decoded = true;
        file.wasDryRun = _state.dryRun;
        _handleFileComplete();
      });
    }
  }

  void _handleFileComplete() {
    _incrementComplete();
    _maybeRename();
    _maybeStopRunning();
    _renameOne();
  }

  void _maybeRename() {
    var start = _lastUpdated;

    // skip leading images without QR
    if (start == 0) {
      while (start < _state.files.length && _state.files[start].decoded && _state.files[start].qr.length == 0) {
        _state.files[start].decoded = true;
        start++;
      }
    }

    if (start >= _state.files.length || _state.files[start].qr.length == 0) return;

    var end = start + 1;
    while (end < _state.files.length && _state.files[end].decoded && _state.files[end].qr.length == 0) {
      end++;
    }

    if (end < _state.files.length && _state.files[end].qr.length == 0) return;

    for (var i = start; i < end; i++) {
      _state.files[i].processed = true;
      _renameFile(_state.files[i], _state.files[start].qr);
    }

    _lastUpdated = end;

    _state.outsideSetState();
  }

  void _renameFile(file, qr) {
    if (_format.indexOf("{qr}") < 0 && file.name.indexOf(qr) >= 0) return;

    var ext = Path.extension(file.name);
    var newName = _format;
    newName = newName.replaceAll("{qr}", qr);
    newName = newName.replaceAll("{file-name}", Path.basenameWithoutExtension(file.name));
    newName = newName.replaceAll("{file-number}", file.fileNumber);
    if (!newName.toLowerCase().endsWith(ext.toLowerCase())) {
      newName += ext;
    }
    var newPath = Path.join(Path.dirname(file.path), newName);
    file.newPath = newPath;

    if (!_state.dryRun) {
      var f = IO.File(file.path);
      f.rename(newPath);
    }
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