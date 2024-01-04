import 'package:flutter/material.dart';

import 'package:qrenamer/file-table-widget.dart';
import 'package:qrenamer/ui-file.dart';
import 'dart:io' as IO;

import 'package:shared_preferences/shared_preferences.dart';

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
  bool isRunning = false;
  bool isDropping = false;
  bool _renameApplied = false;
  int _pctComplete = -1;
  TextEditingController _formatController = TextEditingController();
  late SharedPreferences _prefs;
  late Renamer _renamer;
  final formatter = new Formatter();
  late final _fileTableWidget;

  PageState() {
    _formatController.text = "{qr} {file-name}";
    _renamer = Renamer(this);
    _fileTableWidget = FileTableWidget(this);

    _renamer.addPctListener((pct) {
      if (pct != _pctComplete) {
        setState(() { _pctComplete = pct; });
      }
    });

    _renamer.addCompleteListener(() {
      setState(() { isRunning = false; });
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

  void outsideSetState() {
    this.setState(() { });
  }

  void _updateFormat() {
    formatter.format = _formatController.text;
    _fileTableWidget.outsideSetState();
  }

  void _start() {
    var format = _formatController.text;
    formatter.format = format;
    _prefs.setString("format", format);
    _renamer.start(_fileTableWidget.files);
  }

  void _closeFiles() {
    _fileTableWidget.closeFiles();
    _pctComplete = -1;
  }

  void _toggleRunning() {
    setState(() {
      isRunning = !isRunning;
    });
    if (isRunning) {
      _start();
    }
  }

  void _applyRename() {
    for (var file in _fileTableWidget.files) {
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

  void _undo() {
    for (var file in _fileTableWidget.files) {
      file.processed = false;
      file.decoded = false;
      if (file.path != file.originalPath) {
        var f = IO.File(file.path);
        f.rename(file.originalPath);
        file.path = file.originalPath;
      }
    }
    setState(() {
      _pctComplete = -1;
      isRunning = isRunning;
      _renameApplied = false;
    });
    // TODO: Check that file table widget is updated
    _fileTableWidget.outsideSetState();
  }

  void _toggleCaseTransform() {
    for (var file in _fileTableWidget.files) {
      file.controller.text = file.controller.text.split(RegExp("\\s+"))
        .map((e) => e.length > 0 ? e[0].toUpperCase() + e.substring(1).toLowerCase() : e)
        .join(" ");
      file.qr = file.controller.text;
    }
    _fileTableWidget.outsideSetState();
  }

  void _insertFormatter(String formatter) {
    var text = _formatController.text;
    _formatController.text = "$text$formatter";
    _updateFormat();
  }


  Widget topBar() {
    return Container(
      color: UIColors.gray2,
      child: Row(
        children: [
          BarButton(
            text: "Close Files",
            icon: Icons.close,
            condition: () => _fileTableWidget.files.length > 0 && !isRunning,
            onPressed: _closeFiles,
          ),
          Spacer(flex: 1),
          BarButton(
            text: "Convert to Title Case",
            icon: Icons.format_size,
            condition: () => _fileTableWidget.files.length > 0 && !isRunning,
            onPressed: _toggleCaseTransform,
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
    return Container(
      color: UIColors.gray1,
      child: Row(
        children: [
          Container(padding: EdgeInsets.all(12), child: Text( _pctComplete < 0 ? "" : "$_pctComplete%", style: TextStyle(color: UIColors.text))),
          Spacer(),
          ButtonBar(
            layoutBehavior: ButtonBarLayoutBehavior.padded,
            children: [
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: UIColors.text, backgroundColor: UIColors.gray3,
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
              TextButton(
                style: TextButton.styleFrom(foregroundColor: isRunning ? UIColors.disabled : UIColors.text),
                child: Row(
                  children: [
                    Icon(Icons.check_outlined),
                    Text(" Apply"),
                  ]
                ),
                onPressed: () { if (!isRunning) _applyRename(); },
              ),
              Container(
                width: 10
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: isRunning || !_renameApplied ? UIColors.disabled : UIColors.text),
                child: Row(
                  children: [
                    Icon(Icons.undo),
                    Text(" Undo"),
                  ]
                ),
                onPressed: () { if (!isRunning && _renameApplied) _undo(); },
              ),
              Container(
                width: 10
              ),
            ]
          )
        ]
      )
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          topBar(),
          formatBar(),
          formatGenerators(),
          _fileTableWidget,
          bottomBar(),
        ]
      ),
    );
  }
}