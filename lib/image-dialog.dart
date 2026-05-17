import 'dart:io' as IO;

import 'package:flutter/material.dart';
import 'package:zoom_widget/zoom_widget.dart';

import 'ui-file.dart';
import 'ui-colors.dart';
import 'qr-input-widget.dart';

class ImageDialog {
  static void _reveal(String path) {
    IO.Process.run('/usr/bin/env', ['open', '-R', path]);
  }

  static Future<void> show(BuildContext context, UIFile file) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(file.name),
          backgroundColor: UIColors.gray2,
          iconColor: UIColors.text,
          titleTextStyle: TextStyle(color: UIColors.text),
          content: SizedBox.fromSize(
            size: Size(400.0, 600.0),
            child: Column(
              children: [
                Expanded(
                  child: Zoom(
                    initTotalZoomOut: true,
                    maxScale: 10.0,
                    backgroundColor: UIColors.gray2,
                    canvasColor: UIColors.gray2,
                    enableScroll: false,
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
                QRInputWidget(file, placeholder: "Enter QR Data Manually", color: UIColors.text),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: TextStyle(color: UIColors.text),
              ),
              child: const Text('Show in Finder', style: TextStyle(color: UIColors.text)),
              onPressed: () { _reveal(file.path); },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: TextStyle(color: UIColors.text),
              ),
              child: const Text('Close', style: TextStyle(color: UIColors.text)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
