import 'dart:io' as IO;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ui-file.dart';
import 'file-table-widget.dart';
import 'file-manager.dart';
import 'renamer.dart';
import 'formatter.dart';
import 'bar-button.dart';
import 'ui-colors.dart';

class QRenamerPage extends StatefulWidget {
  QRenamerPage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  PageState createState() => PageState();
}

class PageState extends State<QRenamerPage> {

  // LOCALS
  Map<String, Image> _imgCache = Map<String, Image>();
  bool isDropping = false;
  bool _renameApplied = false;
  bool isRunning = false;
  bool isShowingSettings = false;
  int _pctComplete = -1;
  final _fileManager = FileManager.instance;
  List<UIFile> _files = FileManager.instance.files;
  TextEditingController _formatController = TextEditingController();
  late SharedPreferences _prefs;
  late Renamer _renamer;
  final formatter = new Formatter();
  late final _fileTableWidget;

  PageState() {
    _formatController.text = "{qr} {file-name}";
    formatter.format = _formatController.text;
    _renamer = Renamer();
    _fileTableWidget = FileTableWidget(this);

    _renamer.pctEvent.bind(this, () {
      if (_renamer.pctComplete != _pctComplete) {
        setState(() { _pctComplete = _renamer.pctComplete; });
      }
    });

    _renamer.completeEvent.bind(this, () {
      setState(() { isRunning = _renamer.isRunning; });
    });

    _fileManager.changeEvent.bind(this, () {
      setState(() { _files = _fileManager.files; });
    });

    SharedPreferences.getInstance()
    .then((value) async {
      _prefs = value;
      var savedFormat = _prefs.getString("format");
      if (savedFormat != null) {
        _formatController.text = savedFormat;
      }
    });
  }

  void _updateFormat() {
    formatter.format = _formatController.text;
  }

  void _start() {
    var format = _formatController.text;
    formatter.format = format;
    _prefs.setString("format", format);
    _renamer.start();
    setState(() { isRunning = _renamer.isRunning;_pctComplete = -1; });
  }

  void _stop() {
    _renamer.stop();
    setState(() { isRunning = _renamer.isRunning; });
  }

  void _closeFiles() {
    _fileManager.clear();
    _pctComplete = -1;
  }

  void _toggleRunning() {
    if (_renamer.isRunning) _stop();
    else _start();
  }

  void _applyRename() {
    if (!_canApplyRename()) return;

    for (var file in _fileManager.files) {
      if (file.newPath != file.path) {
        var f = IO.File(file.path);
        f.rename(file.newPath)
        .then((_value) {
          file.path = file.newPath;
        });
      }
    }
    setState(() {
      _renameApplied = true;
    });
  }

  bool _canApplyRename() {
    return !isRunning && _fileManager.hasFiles && _fileManager.files.last.decoded;
  }

  void _undo() {
    for (var file in _fileManager.files) {
      if (file.path != file.originalPath) {
        var f = IO.File(file.path);
        f.rename(file.originalPath);
        file.path = file.originalPath;
      }
    }
    setState(() {
      _renameApplied = false;
    });
    _fileManager.changeEvent.emit();
  }

  void _insertFormatter(String formatter) {
    var text = _formatController.text;
    _formatController.text = "$text$formatter";
    _updateFormat();
  }


  Widget topBar() {
    if (_files.isEmpty) {
      return Container( child: null );
    }
    return Container(
      color: UIColors.gray2,
      child: Row(
        children: [
          Spacer(flex: 1),
          BarButton(
            text: "Close Files",
            icon: Icons.close,
            condition: () => _files.length > 0 && !isRunning,
            onPressed: _closeFiles,
          ),
        ]
      )
    );
  }

  Widget formatBar() {
    return Container(
      color: UIColors.gray4,
      padding: EdgeInsets.only(top: 12, bottom: 8, left: 8, right: 8),
      height: 50,
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.only(left: 4),
            child: Text("Rename to:  ", style: TextStyle(color: UIColors.text)),
          ),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 14, color: UIColors.text),
              controller: _formatController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                border: OutlineInputBorder()
              ),
              onChanged: (_) { _updateFormat(); },
            )
          )
        ]
      )
    );
  }

  Widget formatGenerators() {

    Widget formatButton(name, tag) {
      return Container(
        padding: IO.Platform.isWindows ? EdgeInsets.only(left: 8) : EdgeInsets.zero,
        child: TextButton(
          onPressed: () => _insertFormatter(tag),
          child: Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(6)), color: UIColors.gray3),
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(name, style: TextStyle(fontSize: 12, color: UIColors.text)),
          )
        )
      );
    }

    return Container(
      color: UIColors.gray4,
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          formatButton("QR Data", "{qr}"),
          formatButton("File Name", "{file-name}"),
          formatButton("File Number", "{file-number}"),
        ],
      )
    );
  }

  Widget _formatControls() {
    if (_files.length == 0 || !isShowingSettings) return Container();
    return Column(
      children: [
        formatBar(),
        formatGenerators(),
      ]
    );
  }

  Image readImage(String path) {
    if (_imgCache.containsKey(path)) {
      return _imgCache[path]!;
    }

    var file = IO.File(path);
    var bytes = file.readAsBytesSync();
    var img = Image.memory(
      bytes,
      height: 80,
      cacheHeight: 80,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.none,
    );
    _imgCache[path] = img;
    return img;
  }

  Widget bottomBar() {
    if (_files.isEmpty) {
      return Container( child: null );
    }
    return Container(
      color: UIColors.gray1,
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                setState(() {
                  isShowingSettings = !isShowingSettings;
                });
              },
              icon: Icon(Icons.settings),
              style: IconButton.styleFrom(foregroundColor: isRunning || !_fileManager.hasFiles ? UIColors.disabled : UIColors.text),
            ),
            Container( width: 10 ),
            Container(padding: EdgeInsets.all(12), width: 70.0, child: Text( _pctComplete < 0 ? "" : "$_pctComplete%", style: TextStyle(color: UIColors.text))),
            Expanded(
              child: LinearProgressIndicator(
                value: _pctComplete.toDouble() / 100.0,
                backgroundColor: _pctComplete < 0 ? Colors.transparent : UIColors.gray4,
                valueColor: AlwaysStoppedAnimation(UIColors.green1),
                minHeight: 12,
              )
            ),
            Row(
              children: [
                Container(width: 40),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: _fileManager.hasFiles ? UIColors.text : UIColors.disabled, backgroundColor: UIColors.gray3,
                  ),
                  child: Container(
                    width: 70,
                    child: Row(
                      children: [
                        Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow),
                        Text(isRunning ? ' Stop' : ' Scan'),
                      ]
                    )
                  ),
                  onPressed: _toggleRunning,
                ),
                Container(
                  width: 10
                ),
                Tooltip(
                  message: _renameApplied ? "Restore the original file names." : "Save the updated file names.",
                  child: TextButton(
                    style: _renameApplied
                      ? TextButton.styleFrom(foregroundColor: UIColors.text, minimumSize: Size(100, 45))
                      : TextButton.styleFrom(foregroundColor: _canApplyRename() ? UIColors.text : UIColors.disabled, minimumSize: Size(100, 45)),
                    child: Row(
                      children: [
                        Icon(_renameApplied ? Icons.undo : Icons.check_outlined),
                        Text(_renameApplied ? " Undo" : " Apply"),
                      ]
                    ),
                    onPressed: _renameApplied ? _undo : _applyRename,
                  ),
                ),
                Container(
                  width: 10
                ),
                Tooltip(
                  message: "Close all open files.",
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: UIColors.text),
                    child: Row(
                      children: [
                        Icon(Icons.close),
                        Text(" Close"),
                      ]
                    ),
                    onPressed: _closeFiles,
                  )
                ),
                Container( width: 10),
              ]
            )
          ]
        )
      )
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // topBar(),
          _fileTableWidget,
          _formatControls(),
          bottomBar(),
        ]
      ),
    );
  }
}