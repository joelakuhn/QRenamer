import 'package:flutter/material.dart';

import 'ui-file.dart';
import 'ui-colors.dart';

class QRInputWidget extends StatefulWidget {
  late final UIFile _file;

  QRInputWidget(UIFile file) {
    _file = file;
  }

  @override createState() => QRInputWidgetState(_file);
}

class QRInputWidgetState extends State<QRInputWidget> {
  late UIFile _file;

  QRInputWidgetState(UIFile file) {
    _file = file;
    _file.addChangeListener(() {
      setState(() { _file = file; });
    });
  }

  Widget build(BuildContext context) {
    return TextField(
      controller: _file.controller,
      onChanged: (value) {
        setState(() { _file.qr = value; });
      },
      style: TextStyle(
        color: UIColors.text,
        backgroundColor: Colors.transparent,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.zero
      ),
    );
  }
}
