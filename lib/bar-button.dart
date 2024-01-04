import 'package:flutter/material.dart';

import 'ui-colors.dart';

class BarButton extends StatelessWidget {
  late final String _text;
  late final IconData _icon;
  late final Function _condition;
  late final Function _onPressed;

  BarButton({required String text, required IconData icon, required Function condition, required Function onPressed}) {
    this._icon = icon;
    this._text = text;
    this._condition = condition;
    this._onPressed = onPressed;
  }

  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: 2),
      child: TextButton(
        style: TextButton.styleFrom(
          foregroundColor: _condition() ? UIColors.text : UIColors.disabled, shape: RoundedRectangleBorder(side: BorderSide.none),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          backgroundColor: UIColors.gray3,
        ),
        child: Container (
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Row(children: [ Icon(_icon), Text("  " + _text) ]),
        ),
        onPressed: () { if (_condition()) _onPressed(); }
      )
    );
  }
}