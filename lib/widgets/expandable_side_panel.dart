import 'package:flutter/material.dart';

/// 오른쪽에서 슬라이드인되는 사이드 패널 오버레이.
/// 리스트 형태의 위젯을 넓은 화면으로 보여준다.
void showExpandableSidePanel({
  required BuildContext context,
  required String title,
  required IconData icon,
  required Widget Function(BuildContext context) bodyBuilder,
  double widthFraction = 0.38,
  double minWidth = 420,
  double maxWidth = 600,
  Widget? headerTrailing,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (ctx) => _SidePanelOverlay(
      title: title,
      icon: icon,
      bodyBuilder: bodyBuilder,
      widthFraction: widthFraction,
      minWidth: minWidth,
      maxWidth: maxWidth,
      headerTrailing: headerTrailing,
      onClose: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _SidePanelOverlay extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget Function(BuildContext context) bodyBuilder;
  final double widthFraction;
  final double minWidth;
  final double maxWidth;
  final Widget? headerTrailing;
  final VoidCallback onClose;

  const _SidePanelOverlay({
    required this.title,
    required this.icon,
    required this.bodyBuilder,
    required this.widthFraction,
    required this.minWidth,
    required this.maxWidth,
    this.headerTrailing,
    required this.onClose,
  });

  @override
  State<_SidePanelOverlay> createState() => _SidePanelOverlayState();
}

class _SidePanelOverlayState extends State<_SidePanelOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = (screenWidth * widget.widthFraction)
        .clamp(widget.minWidth, widget.maxWidth);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 딤 배경
          FadeTransition(
            opacity: _fadeAnimation,
            child: GestureDetector(
              onTap: _close,
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
          ),
          // 사이드 패널
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: panelWidth,
            child: SlideTransition(
              position: _slideAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? cs.surfaceContainer
                      : const Color(0xFFFCFCFF),
                  border: Border(
                    left: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
                      blurRadius: 24,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // 헤더
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: cs.outlineVariant.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(widget.icon, color: cs.primary, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: cs.onSurface,
                            ),
                          ),
                          const Spacer(),
                          if (widget.headerTrailing != null) ...[
                            widget.headerTrailing!,
                            const SizedBox(width: 8),
                          ],
                          SizedBox(
                            width: 32,
                            height: 32,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              iconSize: 18,
                              icon: Icon(
                                Icons.close,
                                color: cs.onSurface.withValues(alpha: 0.6),
                              ),
                              onPressed: _close,
                              tooltip: '닫기',
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 본문
                    Expanded(
                      child: widget.bodyBuilder(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
