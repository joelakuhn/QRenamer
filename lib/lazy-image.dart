import 'dart:typed_data';
import 'dart:io' as IO;

import 'package:flutter/material.dart';
import 'package:qrenamer/page.dart';

class LazyImage {
  late Image img;
  late String path;
  late PageState _state;

  static const int CONCURRENCY = 50;
  static int loading = 0;
  static List<LazyImage> waiting = [];

  LazyImage(String path, _state) {
    this.path = path;
    this._state = _state;
    this.img = Image.memory(Uint8List.fromList([
      0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 0x01, 0x00, 0x01, 0x00, 0x80, 0x00, 0x00, 0xff, 0xff, 0xff,
      0x00, 0x00, 0x00, 0x21, 0xf9, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0x2c, 0x00, 0x00, 0x00, 0x00,
      0x01, 0x00, 0x01, 0x00, 0x00, 0x02, 0x02, 0x44, 0x01, 0x00, 0x3b,
    ]));
    maybeLoad();
  }

  void maybeLoad() {
    if (LazyImage.loading < LazyImage.CONCURRENCY) {
      LazyImage.loading += 1;
      IO.File(this.path).readAsBytes().then((bytes) {
        try {
          this.img = Image.memory(bytes,
            height: 80,
            cacheHeight: 80,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.none,
          );
          _state.outsideSetState();
        }
        catch (e) {
          print("Error loading image: $e");
        }
      })
      .whenComplete(() {
        LazyImage.loading -= 1;
        if (LazyImage.waiting.length > 0) {
          LazyImage.waiting.removeAt(0).maybeLoad();
        }
      });
    }
    else {
      LazyImage.waiting.add(this);
    }
  }
}
