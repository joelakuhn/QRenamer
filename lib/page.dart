import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:path/path.dart' as Path;
import 'dart:io' as IO;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';

import 'renamer.dart';
import 'ui-file.dart';

class QRenamerPage extends StatefulWidget {
  QRenamerPage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  PageState createState() => PageState();
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
  static Color blue = Color(0xff1fb4c4);
}

class PageState extends State<QRenamerPage> {

  // LOCALS

  List<UIFile> files = [];
  List<String> _imageExtensions = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tga', 'tiff', 'webp', 'mrw', 'arw',
    'srf', 'sr2', 'mef', 'orf', 'srw', 'erf', 'kdc', 'dcs', 'rw2', 'raf',
    'dcr', 'pef', 'crw', 'iiq', '3fr', 'nrw', 'nef', 'mos', 'cr2', 'ari' ];
  bool isRunning = false;
  bool dryRun = false;
  bool _maximizeAccuracy = false;
  bool _isDropping = false;
  int pctComplete = -1;
  TextEditingController _formatController = TextEditingController();
  SharedPreferences _prefs;
  Renamer _renamer;

  PageState() {
    _formatController.text = "{qr} {file-name}";
    _renamer = Renamer(this);

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
        files = uiFiles;
      });
    }
  }

  void _browseDirectory() async {
    final String directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      var uiFiles = _readDir(directoryPath);
      _sortByFileNumber(uiFiles);
      setState(() {
        files = uiFiles;
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
      files = uiFiles;
    });
  }

  void _start() {
    var format = _formatController.text;
    _prefs.setString("format", format);
    _renamer.start(format, _maximizeAccuracy);
  }

  void _closeFiles() {
    setState(() {
      files = [];
    });
  }

  void _toggleRunning() {
    setState(() {
      isRunning = !isRunning;
    });
    if (isRunning) {
      _start();
    }
  }

  void _toggleDryrun() {
    setState(() {
      dryRun = !dryRun;
    });
  }

  void _undo() {
    isRunning = false;
    for (var file in files) {
      if (file.newPath.length > 0) {
        if (file.processed && !file.wasDryRun) {
          var f = IO.File(file.newPath);
          f.rename(file.path);
        }
      }
      file.newPath = "";
      file.processed = false;
      file.decoded = false;
    }
    setState(() {
      files = files;
      pctComplete = -1;
      isRunning = isRunning;
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
          primary: !isRunning && condition() ? UIColors.text : UIColors.disabled,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          backgroundColor: UIColors.gray3,
        ),
        child: Container (
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [ Icon(icon), Text("  " + text) ]),
        ),
        onPressed: condition() && !isRunning ? onPressed : () {},
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
            condition: () => files.length > 0,
            onPressed: _closeFiles,
          ),
          barButton(
            text: "Undo",
            icon: Icons.undo,
            condition: () => files.any((f) => f.processed || f.decoded),
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
      onDragEntered: () { if (!isRunning) setState(() => _isDropping = true); },
      onDragExited: () { if (!isRunning) setState(() => _isDropping = false); },
      onDragDone: (urls) { if (!isRunning) _handleFileDrop(urls); },
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
      onDragEntered: () { if (!isRunning) setState(() => _isDropping = true); },
      onDragExited: () { if (!isRunning) setState(() => _isDropping = false); },
      onDragDone: (urls) { if (!isRunning) _handleFileDrop(urls); },
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
                children: files.map((f) => TableRow(
                  children: [
                    TableCell(child: Container(
                      width: 20,
                      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      alignment: Alignment.centerLeft,
                      child: Icon(
                        Icons.check_circle,
                        color: f.processed && !f.wasDryRun ? UIColors.green2 : f.decoded && !f.wasDryRun ? UIColors.blue : UIColors.gray3,
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
          Container(padding: EdgeInsets.all(12), child: Text( pctComplete < 0 ? "" : "$pctComplete%", style: TextStyle(color: UIColors.text))),
          Spacer(),
          ButtonBar(
            layoutBehavior: ButtonBarLayoutBehavior.padded,
            children: [
              TextButton(
                style: TextButton.styleFrom(primary: isRunning ? UIColors.disabled : UIColors.text),
                child: Row(
                  children: [
                    Icon(_maximizeAccuracy ? Icons.check_box_outlined : Icons.check_box_outline_blank),
                    Text(" Maximize Accuracy"),
                  ]
                ),
                onPressed: () { if (!isRunning) { setState(() { _maximizeAccuracy = !_maximizeAccuracy; }); } },
              ),
              TextButton(
                style: TextButton.styleFrom(primary: isRunning ?  UIColors.disabled : UIColors.text),
                child: Row(
                  children: [
                    Icon(dryRun ? Icons.check_box_outlined : Icons.check_box_outline_blank),
                    Text(" Dry Run"),
                  ]
                ),
                onPressed: () { if (!isRunning) _toggleDryrun(); },
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
                      Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow),
                      Text(isRunning ? ' Stop' : ' Run'),
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
          files.length > 0 ? fileTable() : openFilesBox(),
          bottomBar(),
        ]
      ),
    );
  }
}