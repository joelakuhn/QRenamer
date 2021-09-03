import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QRenamer',
      debugShowCheckedModeBanner: false,
      home: QRenamerPage(title: 'QRenamer'),
    );
  }
}
