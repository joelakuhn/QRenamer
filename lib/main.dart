import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:path/path.dart' as Path;
import 'dart:io' as IO;
import 'dart:math' as Math;

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
  String _fileNumber;
  int _intFileNumber;
  String qr;
  bool wasDryRun = false;
  bool processed = false;

  UIFile(String path) {
    this.path = path;
    this._newPath = "";
    this._newName = "";
    this.qr = "";
  }

  String _extractFileNumber(String path) {
    var fileNumberMatches = RegExp(r'\d+').allMatches(Path.basenameWithoutExtension(path));
    return fileNumberMatches.length > 0 ? fileNumberMatches.last.group(0) : "";
  }

  String get name { return _name; }
  String get path { return _path; }
  set path(path) {
    _path = path;
    _name = Path.basename(path);
    _fileNumber = _extractFileNumber(path);
    _intFileNumber = _fileNumber == "" ? 0 : int.parse(_fileNumber);
  }

  String get newName { return _newName; }
  String get newPath { return _newPath; }
  set newPath(path) {
    _newPath = path;
    _newName = Path.basename(path);
  }

  String get fileNumber { return _fileNumber; }

  int get intFileNumber { return _intFileNumber; }
}

class UIColors {
  static Color gray1 = Color(0xff0f1113);
  static Color gray2 = Color(0xff191b1f);
  static Color gray3 = Color(0xff2b2f35);
  static Color gray4 = Color(0xff3c4047);
  static Color text = Color(0xffaebcce);
  static Color disabled = Color(0xff474c53);
  static Color icon = Color(0xff6f7a8a);
  static Color green1 = Color(0xff437d6c);
  static Color green2 = Color(0xff00b27d);
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
  bool _maximizeAccuracy = false;
  bool _isDropping = false;
  int _pctComplete = -1;
  QRReaderFFI qrReaderFfi = QRReaderFFI();
  TextEditingController _formatController = TextEditingController();
  SharedPreferences _prefs;

  _MyHomePageState() {

    _formatController.text = "{qr} {file-name}";
    _concurrencyLevel = Math.max(1, (IO.Platform.numberOfProcessors / 2).floor());

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
    files.sort((a, b) {
      if (a.intFileNumber == b.intFileNumber) {
        return a.name.compareTo(b.name);
      }
      else {
        return a.intFileNumber - b.intFileNumber;
      }
    });
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

  void _handleFileDrop(List urls) {
    List<UIFile> uiFiles = [];
    var paths = urls.map((url) => url.toFilePath());
    
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

  String _format = "";
  int _concurrencyLevel = 1;
  int _renameIndex = 0;
  int _maxSize = 0;
  int _complete = 0;
  int _lastUpdated = 0;

  void _rename() async {
    _format = _formatController.text;
    _renameIndex = 0;
    _maxSize = _maximizeAccuracy ? 0 : 1500;
    _complete = 0;
    _lastUpdated = 0;

    _prefs.setString("format", _format);
    for (var _ = 0; _ < _concurrencyLevel; _++) {
      _renameOne();
    }
  }

  void _renameOne() async {
    if (!_isRunning) return;
    if (_renameIndex >= _files.length) return;

    var file = _files[_renameIndex++];
  
    if (file.processed && !file.wasDryRun) {
      _handleFileComplete();
    }
    else {
      qrReaderFfi.read_qr(file.path, _maxSize)
      .then((qr) {
        if (!_isRunning) return;
        if (qr.length > 0) file.qr = qr;

        _maybeRename();
      })
      .whenComplete(() {
        file.processed = true;
        file.wasDryRun = _dryRun;
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
      while (start < _files.length && _files[start].processed && _files[start].qr.length == 0) {
        start++;
      }
    }

    if (start >= _files.length || _files[start].qr.length == 0) return;

    var end = start + 1;
    while (end < _files.length && _files[end].processed && _files[end].qr.length == 0) {
      end++;
    }

    if (end < _files.length && _files[end].qr.length == 0) return;

    for (var i = start; i < end; i++) {
      _renameFile(_files[i], _files[start].qr);
    }

    _lastUpdated = end;

    setState(() { _files = _files; });
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

    if (!_dryRun) {
      var f = IO.File(file.path);
      f.rename(newPath);
    }
  }

  void _incrementComplete() {
    setState(() {
      _pctComplete = (++_complete / _files.length * 100).round();
    });
  }

  void _maybeStopRunning() {
    if (_complete >= _files.length) {
      _stopRunning();
    }
  }

  void _stopRunning() {
    if (_isRunning) {
      setState(() {
        _isRunning = false;
      });
    }
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

    Widget barButton({String text, IconData icon, Function condition, Function onPressed}) {
    return Container(
      padding: EdgeInsets.only(right: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(side: BorderSide.none),
          primary: !_isRunning && condition() ? UIColors.text : UIColors.disabled,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          backgroundColor: UIColors.gray3,
        ),
        child: Container (
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [ Icon(icon), Text("  " + text) ]),
        ),
        onPressed: condition() && !_isRunning ? onPressed : () {},
      )
    );
  }

  Widget topBar() {


    return Container(
      color: UIColors.gray2,
      child: Row(
        children: [
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

  Widget openFilesBox() {
    return DropTarget(
      onDragEntered: () { if (!_isRunning) setState(() => _isDropping = true); },
      onDragExited: () { if (!_isRunning) setState(() => _isDropping = false); },
      onDragDone: (urls) { if (!_isRunning) _handleFileDrop(urls); },
      child: Expanded(
        child: Container(
          color: _isDropping ? UIColors.green1 : UIColors.gray2,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text("Drop Files Here", style: TextStyle(fontSize: 24, color: UIColors.text))
                ),
                Container(
                  padding: EdgeInsets.only(bottom: 26),
                  child: Text("or", style: TextStyle(fontSize: 14, color: UIColors.text))
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                  ]
                )
              ],
            )
          )
        )
      )
    );
  }

  Widget fileTable() {
    return DropTarget(
      onDragEntered: () { if (!_isRunning) setState(() => _isDropping = true); },
      onDragExited: () { if (!_isRunning) setState(() => _isDropping = false); },
      onDragDone: (urls) { if (!_isRunning) _handleFileDrop(urls); },
      child: Expanded(
        child: Container(
          color: _isDropping ? UIColors.green1 : UIColors.gray2,
          child: Scrollbar(
            child: SingleChildScrollView(
              child: Table(
                columnWidths: {
                  0: FixedColumnWidth(36),
                },
                border: TableBorder(horizontalInside: BorderSide(width: 1, color: UIColors.green1)),
                children: _files.map((f) => TableRow(
                  children: [
                    TableCell(child: Container(
                      width: 20,
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.check_circle,
                        color: f.processed && !f.wasDryRun ? UIColors.green2 : UIColors.gray3,
                      ),
                    )),
                    TableCell(child: Container(
                      padding: EdgeInsets.all(12),
                      alignment: Alignment.centerLeft,
                      child: Text(Path.basename(f.path), style: TextStyle(color: UIColors.text))
                    )),
                    TableCell(child: Container(
                      padding: EdgeInsets.all(12),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        Path.basename(f.newPath.length > 0 ? f.newPath : "unchanged"),
                        style: TextStyle(color: f.newPath.length > 0 ? UIColors.text : UIColors.disabled))
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
      color: UIColors.gray1,
      child: Row(
        children: [
          Container(padding: EdgeInsets.all(12), child: Text( _pctComplete < 0 ? "" : "$_pctComplete%", style: TextStyle(color: UIColors.text))),
          Spacer(),
          ButtonBar(
            layoutBehavior: ButtonBarLayoutBehavior.padded,
            children: [
              TextButton(
                style: TextButton.styleFrom(primary: _isRunning ? UIColors.disabled : UIColors.text),
                child: Row(
                  children: [
                    Icon(_maximizeAccuracy ? Icons.check_box_outlined : Icons.check_box_outline_blank),
                    Text(" Maximize Accuracy"),
                  ]
                ),
                onPressed: () { if (!_isRunning) { setState(() { _maximizeAccuracy = !_maximizeAccuracy; }); } },
              ),
              TextButton(
                style: TextButton.styleFrom(primary: _isRunning ?  UIColors.disabled : UIColors.text),
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
                  primary: UIColors.text,
                  backgroundColor: UIColors.gray3,
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
          _files.length > 0 ? fileTable() : openFilesBox(),
          bottomBar(),
        ]
      ),
    );
  }
}
