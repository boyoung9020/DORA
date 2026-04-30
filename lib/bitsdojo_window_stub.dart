// Stub file for bitsdojo_window when running on web
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

/// 타이틀바 영역 컨테이너 — 웹에서는 자식만 렌더링
class WindowTitleBarBox extends StatelessWidget {
  final Widget child;
  const WindowTitleBarBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) => child;
}

/// 윈도우 드래그 영역 — 웹에서는 자식만 렌더링
class MoveWindow extends StatelessWidget {
  final Widget? child;
  const MoveWindow({super.key, this.child});

  @override
  Widget build(BuildContext context) => child ?? const SizedBox.shrink();
}

class WindowButtonColors {
  final Color? iconNormal;
  final Color? iconMouseOver;
  final Color? iconMouseDown;
  final Color? mouseOver;
  final Color? mouseDown;
  final Color? normal;

  const WindowButtonColors({
    this.iconNormal,
    this.iconMouseOver,
    this.iconMouseDown,
    this.mouseOver,
    this.mouseDown,
    this.normal,
  });
}

/// 웹에서는 윈도우 버튼이 의미 없으므로 빈 위젯
class _NoopWindowButton extends StatelessWidget {
  const _NoopWindowButton();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class MinimizeWindowButton extends StatelessWidget {
  final WindowButtonColors? colors;
  final bool? animate;
  const MinimizeWindowButton({super.key, this.colors, this.animate});

  @override
  Widget build(BuildContext context) => const _NoopWindowButton();
}

class MaximizeWindowButton extends StatelessWidget {
  final WindowButtonColors? colors;
  final bool? animate;
  const MaximizeWindowButton({super.key, this.colors, this.animate});

  @override
  Widget build(BuildContext context) => const _NoopWindowButton();
}

class CloseWindowButton extends StatelessWidget {
  final WindowButtonColors? colors;
  final bool? animate;
  const CloseWindowButton({super.key, this.colors, this.animate});

  @override
  Widget build(BuildContext context) => const _NoopWindowButton();
}
