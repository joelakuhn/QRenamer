import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:path/path.dart' as Path;
import 'dart:io' as IO;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import 'qr-reader-ffi.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRenamer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'QRenamer'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class UIFile {
  String _path;
  String _name;
  String _newPath;
  String _newName;
  String qr;
  bool wasDryRun = false;
  bool processed = false;

  UIFile(String path) {
    this.path = path;
    this._newPath = "";
    this._newName = "";
    this.qr = "";
  }

  String get name { return _name; }
  String get path { return _path; }
  set path(path) {
    _path = path;
    _name = Path.basename(path);
  }

  String get newName { return _newName; }
  String get newPath { return _newPath; }
  set newPath(path) {
    _newPath = path;
    _newName = Path.basename(path);
  }
}

class _MyHomePageState extends State<MyHomePage> {

  // LOCALS

  List<UIFile> _files = [];
  List<String> _imageExtensions = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tga', 'tiff', 'webp', 'mrw', 'arw',
    'srf', 'sr2', 'mef', 'orf', 'srw', 'erf', 'kdc', 'dcs', 'rw2', 'raf',
    'dcr', 'pef', 'crw', 'iiq', '3fr', 'nrw', 'nef', 'mos', 'cr2', 'ari' ];
  bool _isRunning = false;
  bool _dryRun = false;
  bool _prioritizeAccuracy = false;
  bool _isDropping = false;
  int _pctComplete = -1;
  QRReaderFFI qrReaderFfi = QRReaderFFI();
  TextEditingController _formatController = TextEditingController();
  SharedPreferences _prefs;

  _MyHomePageState() {

    _formatController.text = "{qr} {file-name}";

    SharedPreferences.getInstance()
    .then((value) async {
      _prefs = value;
      var savedFormat = _prefs.getString("format");
      if (savedFormat != null) {
        _formatController.text = savedFormat;
      }
    });
  }

  void _sortByFileNumber(List<UIFile> files) {
    files.sort((a,b) => Path.basename(a.path).compareTo(Path.basename(b.path)));
  }

  void _browseFiles() async {
    final typeGroup = XTypeGroup(label: 'images', extensions: _imageExtensions);
    var xfiles = await openFiles(acceptedTypeGroups: [ typeGroup ]);
    if (xfiles.length > 0) {
      var uiFiles = xfiles.map((xfile) => UIFile(xfile.path)).toList();
      _sortByFileNumber(uiFiles);
      setState(() {
        _files = uiFiles;
      });
    }
  }

  void _browseDirectory() async {
    final String directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      var uiFiles = _readDir(directoryPath);
      _sortByFileNumber(uiFiles);
      setState(() {
        _files = uiFiles;
      });
    }
  }

  List<UIFile> _readDir(String path) {
    List<UIFile> uiFiles = [];
    var dirFiles = IO.Directory(path).listSync();
    for (var dirFile in dirFiles) {
      if (IO.FileSystemEntity.isFileSync(dirFile.path)) {
        var ext = Path.extension(dirFile.path).replaceFirst(".", "").toLowerCase();
        if (_imageExtensions.any((imgExt) => imgExt == ext)) {
          uiFiles.add(UIFile(dirFile.path));
        }
      }
    }
    return uiFiles;
  }

  String _fixPath(String path) {
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    path = path.replaceAll('/', r'\');
    return path;
  }

  void _handleFileDrop(List urls) {
    List<UIFile> uiFiles = [];
    var paths = IO.Platform.isWindows
      ? urls.map((url) => _fixPath(url.path))
      : urls.map((url) => url.path);
    
    for (var path in paths) {
      if (IO.FileSystemEntity.isDirectorySync(path)) {
        uiFiles.addAll(_readDir(path));
      }
      else {
        uiFiles.add(UIFile(path));
      }
    }
    _sortByFileNumber(uiFiles);
    setState(() {
      _files = uiFiles;
    });
  }

  void _closeFiles() {
    setState(() {
      _files = [];
    });
  }

  void _toggleRunning() {
    setState(() {
      _isRunning = !_isRunning;
    });
    if (_isRunning) {
      _rename();
    }
  }

  void _toggleDryrun() {
    setState(() {
      _dryRun = !_dryRun;
    });
  }

  void _rename() async {
    var format = _formatController.text;
    _prefs.setString("format", format);

    var lastQr = "";
    var complete = 0;
    var max_size = _prioritizeAccuracy ? 0 : 1500;
    for (var file in _files) {
      if (!_isRunning) break;
      if (file.processed && !file.wasDryRun) {
        lastQr = file.qr;
        complete += 1;
        continue;
      }
      final qr = (await qrReaderFfi.read_qr(file.path, max_size)).trim();
      if (!_isRunning) break;
      if (qr.length > 0) {
        lastQr = qr;
      }
      if (lastQr.length > 0) {
        var ext = Path.extension(file.name);
        var fileNumberMatches = RegExp(r'\d+').allMatches(file.name);
        var fileNumber = fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0) : "";
        var newName = format;
        newName = newName.replaceAll("{qr}", "$lastQr");
        newName = newName.replaceAll("{file-name}", Path.basenameWithoutExtension(file.name));
        newName = newName.replaceAll("{file-number}", fileNumber);
        if (!newName.toLowerCase().endsWith(ext.toLowerCase())) {
          newName += ext;
        }
        var newPath = Path.join(Path.dirname(file.path), newName);
        file.newPath = newPath;

        if (!_dryRun) {
          var f = IO.File(file.path);
          f.rename(newPath);
        }
      }
      file.processed = true;
      file.wasDryRun = _dryRun;
      file.qr = lastQr;
      complete += 1;
      setState(() {
        _files = _files;
        _pctComplete = (complete / _files.length * 100).round();
      });
    }
    setState(() {
      _isRunning = false;
    });
  }

  void _undo() {
    _isRunning = false;
    for (var file in _files) {
      if (file.newPath.length > 0) {
        if (file.processed && !file.wasDryRun) {
          var f = IO.File(file.newPath);
          f.rename(file.path);
        }
      }
      file.newPath = "";
      file.processed = false;
    }
    setState(() {
      _files = _files;
      _pctComplete = -1;
      _isRunning = _isRunning;
    });
  }

  void _insertFormatter(String formatter) {
    var text = _formatController.text;
    _formatController.text = "$text$formatter";
  }

  Widget topBar() {
    TextButton barButton({String text, IconData icon, Function condition, Function onPressed}) {
      return TextButton(
        style: TextButton.styleFrom(
          primary: !_isRunning && condition() ? Colors.grey[800] : Colors.grey[500],
          backgroundColor: Colors.grey[200],
        ),
        child: Container (
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [ Icon(icon), Text("  " + text) ]),
        ),
        onPressed: condition() && !_isRunning ? onPressed : () {},
      );
    }

    return Container(
      color: Colors.grey[300],
      child: Row(
        children: [
          ButtonBar(
            children:[
              barButton(
                text: "Open Files",
                icon: Icons.image,
                condition: () => true,
                onPressed: _browseFiles
              ),
              barButton(
                text: "Open Folder",
                icon: Icons.folder,
                condition: () => true,
                onPressed: _browseDirectory
              ),
              barButton(
                text: "Close Files",
                icon: Icons.close,
                condition: () => _files.length > 0,
                onPressed: _closeFiles,
              ),
              barButton(
                text: "Undo",
                icon: Icons.undo,
                condition: () => _files.any((f) => f.processed),
                onPressed: _undo,
              )
            ]
          )
        ]
      )
    );
  }

  Widget formatBar() {
    return Container(
      color: Colors.grey[200],
      padding: EdgeInsets.only(top: 12, bottom: 8, left: 8, right: 8),
      height: 50,
      child: Row(
        children: [
          Text("Rename Format:   "),
          Expanded(
            child: TextField(
              style: TextStyle(fontSize: 14),
              controller: _formatController,
              decoration: InputDecoration(
                contentPadding: EdgeInsets.all(4),
                border: OutlineInputBorder(),
              ),
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
            decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(6)), color: Colors.grey[350]),
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            child: Text(name, style: TextStyle(fontSize: 12, color: Colors.grey[900])),
          )
        )
      );
    }

    return Container(
      color: Colors.grey[200],
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

  Widget fileTable() {
    return
    DropTarget(
      onDragEntered: () { if (!_isRunning) setState(() => _isDropping = true); },
      onDragExited: () { if (!_isRunning) setState(() => _isDropping = false); },
      onDragDone: (urls) { if (!_isRunning) _handleFileDrop(urls); },
      child: Expanded(
        child: Container(
          height: 100,
          color: _isDropping ? Colors.blue[100] : Colors.white,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: {
                  0: FixedColumnWidth(36),
                },
                border: TableBorder(horizontalInside: BorderSide(width: 1, color: Colors.grey[400])),
                children: _files.map((f) => TableRow(
                  children: [
                    TableCell(child: Container(
                      width: 20,
                      padding: EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12),
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.check_circle,
                        color: f.processed && !f.wasDryRun ? Colors.green[400] : Colors.grey[300],
                      ),
                    )),
                    TableCell(child: Container(
                      padding: EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(Path.basename(f.path), style: TextStyle(color: Colors.grey[900]))
                    )),
                    TableCell(child: Container(
                      padding: EdgeInsets.only(left: 12, top: 8, bottom: 8, right: 12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Path.basename(f.newPath.length > 0 ? f.newPath : "unchanged"),
                        style: TextStyle(color: f.newPath.length > 0 ? Colors.grey[900] : Colors.grey[500]))
                    ))
                  ]
                )).toList(),
              )
            )
          )
        )
      )
    );
  }

  Widget bottomBar() {
    return Container(
      color: Colors.grey[300],
      child: Row(
        children: [
          Container(padding: EdgeInsets.all(12), child: Text( _pctComplete < 0 ? "" : "$_pctComplete%")),
          Spacer(),
          ButtonBar(
            layoutBehavior: ButtonBarLayoutBehavior.padded,
            children: [
              TextButton(
                style: TextButton.styleFrom(primary: _isRunning ? Colors.grey[400] : Colors.grey[800]),
                child: Row(
                  children: [
                    Icon(_prioritizeAccuracy ? Icons.check_box_outlined : Icons.check_box_outline_blank),
                    Text(" Prioritize Accuracy"),
                  ]
                ),
                onPressed: () { if (!_isRunning) { setState(() { _prioritizeAccuracy = !_prioritizeAccuracy; }); } },
              ),
              TextButton(
                style: TextButton.styleFrom(primary: _isRunning ? Colors.grey[400] : Colors.grey[800]),
                child: Row(
                  children: [
                    Icon(_dryRun ? Icons.check_box_outlined : Icons.check_box_outline_blank),
                    Text(" Dry Run"),
                  ]
                ),
                onPressed: () { if (!_isRunning) _toggleDryrun(); },
              ),
              Container(
                width: 10
              ),
              TextButton(
                style: TextButton.styleFrom(
                  primary: Colors.grey[800],
                  backgroundColor: Colors.grey[200],
                ),
                child: Container(
                  width: 70,
                  child: Row(
                    children: [
                      Icon(_isRunning ? Icons.stop_rounded : Icons.play_arrow),
                      Text(_isRunning ? ' Stop' : ' Run'),
                    ]
                  )
                ),
                onPressed: _toggleRunning,
              )
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
          fileTable(),
          bottomBar(),
        ]
      ),
    );
  }
}
