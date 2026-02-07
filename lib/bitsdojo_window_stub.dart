// Stub file for bitsdojo_window when running on web
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppWindow {
  Size get size => Size.zero;
  set size(Size value) {}
  Size get minSize => Size.zero;
  set minSize(Size value) {}
  Alignment get alignment => Alignment.center;
  set alignment(Alignment value) {}
  String get title => '';
  set title(String value) {}
  void show() {}
}

final appWindow = AppWindow();

void doWhenWindowReady(VoidCallback callback) {
  // 웹에서는 아무것도 하지 않음
}
