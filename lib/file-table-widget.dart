import 'dart:io' as IO;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:qrenamer/lazy-image.dart';
import 'package:zoom_widget/zoom_widget.dart';

import 'qr-indicator-widget.dart';
import 'qr-input-widget.dart';
import 'string-brigade.dart';
import 'page.dart';
import 'ui-file.dart';
import 'bar-button.dart';
import 'ui-colors.dart';
import 'qr-result-widget.dart';
import 'file-manager.dart';

class FileTableWidget extends StatefulWidget {
  late final FileTableWidgetState _state;

  FileTableWidget(PageState parent) {
    _state = FileTableWidgetState(parent);
  }

  @override
  createState() => _state;
}

class FileTableWidgetState extends State<FileTableWidget> {
  late PageState _parent;
  final _pageScrollController = ScrollController();
  final _fileManager = FileManager.instance;
  List<UIFile> _files = FileManager.instance.files;
  final List<String> imageExtensions = [
    'jpg', 'jpeg', 'png', 'bmp', 'gif', 'tga', 'tiff', 'webp', 'mrw', 'arw',
    'srf', 'sr2', 'mef', 'orf', 'srw', 'erf', 'kdc', 'dcs', 'rw2', 'raf',
    'dcr', 'pef', 'crw', 'iiq', '3fr', 'nrw', 'nef', 'mos', 'cr2', 'ari' ];

  FileTableWidgetState(PageState parent) {
    _parent = parent;
    _fileManager.changeEvent.bind(this, () {
      setState(() { _files = _fileManager.files; });
    });
  }

  _reveal(String path) {
    IO.Process.run('/usr/bin/env', ['open', '-R', path]);
  }

  Future<void> _dialogBuilder(BuildContext context, UIFile file) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(file.name),
          content: SizedBox.fromSize(
            size: Size(400.0, 600.0),
            child: Column(
              children: [
                Expanded(
                  child: Zoom(
                    initTotalZoomOut: true,
                    maxScale: 10.0,
                    child: Center(
                      child: Image.file(
                        width: 400.0,
                        height: 600.0,
                        IO.File(file.path),
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  )
                ),
                TextField(
                  controller: file.controller,
                  decoration: InputDecoration(
                    hint: Text("QR Data", style: TextStyle(color: Colors.grey))
                  ),
                )
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Show in Finder'),
              onPressed: () { _reveal(file.path); },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Close'),
              onPressed: () { Navigator.of(context).pop(); },
            ),
          ],
        );
      },
    );
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
    StringBrigade.reset();
    for (var file in files) {
      file.reset();
    }
  }

  void _browseFiles() async {
    final typeGroup = XTypeGroup(label: 'images', extensions: imageExtensions);
    var xfiles = await openFiles(acceptedTypeGroups: [ typeGroup ]);
    if (xfiles.length > 0) {
      var uiFiles = xfiles.map((xfile) => UIFile(xfile.path, _parent.formatter)).toList();
      _sortByFileNumber(uiFiles);
      _fileManager.files = uiFiles;
    }
  }

  void _browseDirectory() async {
    final String? directoryPath = await getDirectoryPath();
    if (directoryPath != null) {
      var uiFiles = _readDir(directoryPath);
      _sortByFileNumber(uiFiles);
      _fileManager.files = uiFiles;
    }
  }

  List<UIFile> _readDir(String path) {
    List<UIFile> uiFiles = [];
    var dirFiles = IO.Directory(path).listSync();
    for (var dirFile in dirFiles) {
      if (IO.FileSystemEntity.isFileSync(dirFile.path)) {
        var ext = Path.extension(dirFile.path).replaceFirst(".", "").toLowerCase();
        if (imageExtensions.any((imgExt) => imgExt == ext)) {
          uiFiles.add(UIFile(dirFile.path, _parent.formatter));
        }
      }
    }
    return uiFiles;
  }

  void _handleFileDrop(List urls) {
    List<UIFile> uiFiles = [];
    var paths = urls.map((url) => url.path);

    for (var path in paths) {
      if (IO.FileSystemEntity.isDirectorySync(path)) {
        uiFiles.addAll(_readDir(path));
      }
      else {
        uiFiles.add(UIFile(path, _parent.formatter));
      }
    }
    _sortByFileNumber(uiFiles);
    _fileManager.files.clear();
    _fileManager.files = uiFiles;
  }

  Widget _openFilesBox() {
    return DropTarget(
      onDragEntered: (_) { if (!_parent.isRunning) setState(() => _parent.isDropping = true ); },
      onDragExited: (_) { if (!_parent.isRunning) setState(() => _parent.isDropping = false ); },
      onDragDone: (evt) { if (!_parent.isRunning) _handleFileDrop(evt.files); },
      child: Expanded(
        child: Container(
          color: _parent.isDropping ? UIColors.green1 : UIColors.gray2,
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
                  BarButton(
                      text: "Open Files",
                      icon: Icons.image,
                      condition: () => !_parent.isRunning,
                      onPressed: _browseFiles
                    ),
                    BarButton(
                      text: "Open Folder",
                      icon: Icons.folder,
                      condition: () => !_parent.isRunning,
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

  List<TableRow> _tableRows() {
    var rows = [ TableRow(
      children: [
        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12), child: Text(""))),
        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12), child: Text(""))),
        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12), child: Text("File Name", style: TextStyle(color: Colors.white)))),
        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12), child: Text("QR Data", style: TextStyle(color: Colors.white)))),
        TableCell(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12), child: Text("New File Name", style: TextStyle(color: Colors.white)))),
      ]
    ) ];
    rows.addAll(_files.map((f) {
      return TableRow(
        children: [
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              width: 20,
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              alignment: Alignment.centerLeft,
              child: QRIndicatorWidget(f),
            )
          ),
          TableCell(
            child: InkWell(
              child: LazyImage(f.path),
              onTap: () => _dialogBuilder(context, f),
            )
          ),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              alignment: Alignment.centerLeft,
              child: InkWell(
                child: Text(f.name, style: TextStyle(color: UIColors.text)),
                onTap: () => _dialogBuilder(context, f),
              )
            )
          ),
          TableCell(child: Container(
            padding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
            alignment: Alignment.centerLeft,
            height: 80,
            child: QRInputWidget(f),
          )),
          TableCell(
            verticalAlignment: TableCellVerticalAlignment.middle,
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              alignment: Alignment.centerLeft,
              child: QRResultWidget(f),
            )
          )
        ]
      );
    }));
    return rows;
  }

  Widget _table() {
    return Expanded(
      child: Container(
        color: _parent.isDropping ? UIColors.green1 : UIColors.gray2,
        child: RawScrollbar(
          trackVisibility: true,
          thumbVisibility: true,
          trackColor: Colors.white10,
          child: SingleChildScrollView(
            controller: _pageScrollController,
            child: Table(
              columnWidths: {
                0: FixedColumnWidth(50),
                1: FixedColumnWidth(80),
              },
              border: TableBorder(horizontalInside: BorderSide(width: 1, color: UIColors.green1)),
              children: _tableRows(),
            )
          ),
          controller: _pageScrollController,
        )
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: _files.length > 0 ? _table() : _openFilesBox()
    );
  }
}
