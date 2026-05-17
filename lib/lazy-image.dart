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
  static Image transparentPixel = Image.memory(base64Decode("R0lGODlhAQABAAAAACH5BAEAAAAALAAAAAABAAEAAAIBAAA="), width: 120, height: 120);

  LazyImageState(String path) {
    this.path = path;
    this.img = transparentPixel;
    maybeLoad();
  }

  @override
  void dispose() {
    super.dispose();
    img.image.evict();
  }

  void maybeLoad() {
    if (LazyImageState.loading < CONCURRENCY) {
      LazyImageState.loading += 1;
      IO.File(this.path).readAsBytes().then((bytes) {
        var original = MemoryImage(bytes);
        var resized = ResizeImage(original, height: 120);
        original.evict();
        try {
          setState(() {
            this.img = Image(image: resized);
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
