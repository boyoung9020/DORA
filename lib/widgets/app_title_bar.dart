import 'package:flutter/material.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

/// 공통 윈도우 타이틀바 위젯
///
/// - 기본 Win32 타이틀바 영역(WindowTitleBarBox)과
///   추가 콘텐츠 영역을 한 번에 렌더링
/// - leadingWidth로 사이드바 공간을 확보할 수 있음
/// - extraHeight로 타이틀바 하단 커스텀 영역 높이를 지정
class AppTitleBar extends StatelessWidget {
  final Color backgroundColor;
  final double leadingWidth;
  final double extraHeight;
  final EdgeInsetsGeometry buttonPadding;
  final Widget? extraContent;

  const AppTitleBar({
    super.key,
    required this.backgroundColor,
    this.leadingWidth = 0,
    this.extraHeight = 0,
    this.buttonPadding = const EdgeInsets.only(top: 3),
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget buildLeadingPlaceholder() {
      return leadingWidth > 0
          ? SizedBox(width: leadingWidth)
          : const SizedBox.shrink();
    }

    return Column(
      children: [
        WindowTitleBarBox(
          child: Container(
            color: backgroundColor,
            child: Row(
              children: [
                buildLeadingPlaceholder(),
                Expanded(
                  child: MoveWindow(
                    child: Padding(
                      padding: buttonPadding,
                      child: Row(
                        children: [
                          const Spacer(),
                          MinimizeWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface.withOpacity(0.7),
                              iconMouseOver: colorScheme.primary,
                              mouseOver: colorScheme.primary.withOpacity(0.1),
                              mouseDown: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          MaximizeWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface.withOpacity(0.7),
                              iconMouseOver: colorScheme.primary,
                              mouseOver: colorScheme.primary.withOpacity(0.1),
                              mouseDown: colorScheme.primary.withOpacity(0.2),
                            ),
                          ),
                          CloseWindowButton(
                            colors: WindowButtonColors(
                              iconNormal: colorScheme.onSurface.withOpacity(0.7),
                              iconMouseOver: Colors.white,
                              mouseOver: Colors.red,
                              mouseDown: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (extraHeight > 0)
          Container(
            height: extraHeight,
            color: backgroundColor,
            child: Row(
              children: [
                buildLeadingPlaceholder(),
                Expanded(child: extraContent ?? const SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }
}

