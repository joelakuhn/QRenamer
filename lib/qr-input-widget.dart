import 'package:flutter/material.dart';

import 'ui-file.dart';
import 'ui-colors.dart';

class QRInputWidget extends StatefulWidget {
  late final UIFile _file;
  String? _placeholder;
  Color? _color;

  QRInputWidget(UIFile file, {String? placeholder, Color? color}) {
    _file = file;
    _placeholder = placeholder;
    _color = color;
  }

  @override createState() => QRInputWidgetState(_file, _placeholder, _color);
}

class QRInputWidgetState extends State<QRInputWidget> {
  late UIFile _file;
  String? _placeholder;
  Color? _color;

  QRInputWidgetState(UIFile file, String? placeholder, Color? color) {
    _file = file;
    _placeholder = placeholder;
    _color = color;
    _file.onChange.bind(this, () {
      setState(() { _file = file; });
    });
  }

  Widget build(BuildContext context) {
    return TextField(
      controller: _file.controller,
      onChanged: (value) {
        _file.qr = value;
      },
      style: TextStyle(
        color: _color == null ? UIColors.text : Colors.black,
        backgroundColor: Colors.transparent,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        contentPadding: EdgeInsets.zero,
        hint: _placeholder == null
        ? null
        : Text("QR Data", style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
