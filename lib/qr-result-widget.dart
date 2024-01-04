import 'package:flutter/material.dart';
import 'package:path/path.dart' as Path;
import 'ui-file.dart';
import 'ui-colors.dart';

class QRResultWidget extends StatefulWidget {
  late final UIFile _file;

  QRResultWidget(UIFile file) {
    _file = file;
  }

  @override
  createState() => QRResultWidgetState(_file);
}

class QRResultWidgetState extends State<QRResultWidget> {
  late UIFile _file;

  QRResultWidgetState(UIFile file) {
    _file = file;
    _file.addChangeListener(() {
      setState(() { _file = _file; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      Path.basename(_file.qr != "" ? _file.newPath : "unchanged"),
      style: TextStyle(color: _file.newPath.length > 0 ? UIColors.text : UIColors.disabled)
    );
  }
}
