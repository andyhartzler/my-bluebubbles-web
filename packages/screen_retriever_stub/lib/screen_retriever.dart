library screen_retriever;

import 'package:flutter/material.dart';

class Display {
  final Size size;

  const Display({this.size = const Size(1280, 720)});
}

class ScreenRetriever {
  ScreenRetriever._();

  static final ScreenRetriever instance = ScreenRetriever._();

  Future<Display> getPrimaryDisplay() async => const Display();
}
