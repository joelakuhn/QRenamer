import 'package:flutter/material.dart';
import 'ui-file.dart';
import 'ui-colors.dart';

class QRIndicatorWidget extends StatefulWidget {
  late final UIFile _file;

  QRIndicatorWidget(UIFile file) {
    _file = file;
  }

  @override
  createState() => QRIndicatorWidgetState(_file);
}

class QRIndicatorWidgetState extends State<QRIndicatorWidget> {
  late UIFile _file;

  QRIndicatorWidgetState(UIFile file) {
    _file = file;
    _file.onChange.bind(this, () {
      if (mounted) setState(() { _file = _file; });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.check_circle,
      color: _file.processed ? UIColors.green2 : _file.decoded ? UIColors.blue : UIColors.gray3,
    );
  }
}
