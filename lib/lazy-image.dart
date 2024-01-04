import 'dart:convert';
import 'dart:io' as IO;

import 'package:flutter/material.dart';

class LazyImage extends StatefulWidget {
  late final String path;

  LazyImage(String path) {
    this.path = path;
  }

  @override
  State<StatefulWidget> createState() {
    return LazyImageState(path);
  }
}

class LazyImageState extends State<LazyImage> {
  late Image img;
  late String path;

  static const int CONCURRENCY = 50;
  static int loading = 0;
  static List<LazyImageState> waiting = [];
  static Image transparentPixel = Image.memory(base64Decode("R0lGODlhAQABAAAAACH5BAEAAAAALAAAAAABAAEAAAIBAAA="));

  LazyImageState(String path) {
    this.path = path;
    this.img = transparentPixel;
    maybeLoad();
  }

  void maybeLoad() {
    if (LazyImageState.loading < CONCURRENCY) {
      LazyImageState.loading += 1;
      IO.File(this.path).readAsBytes().then((bytes) {
        try {
          setState(() {
            this.img = Image.memory(bytes,
              height: 80,
              cacheHeight: 80,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            );
          });
        }
        catch (e) {
          print("Error loading image: $e");
        }
      })
      .whenComplete(() {
        LazyImageState.loading -= 1;
        if (LazyImageState.waiting.length > 0) {
          LazyImageState.waiting.removeAt(0).maybeLoad();
        }
      });
    }
    else {
      LazyImageState.waiting.add(this);
    }
  }

  Widget build (BuildContext context) {
    return img;
  }
}
