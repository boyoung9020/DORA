import 'package:flutter/material.dart';

/// 移대뱶 而⑦뀒?대꼫 ?꾩젽
///
/// ?쇱씠??紐⑤뱶: ?쒕갚 諛곌꼍 + 誘몄꽭 ?뚮몢由?+ 洹몃┝????諛곌꼍 ?鍮??뺤떎??援щ텇
/// ?ㅽ겕 紐⑤뱶: ?대몢??諛곌꼍 + 釉붾윭 ?④낵
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final Color borderColor;
  final double borderWidth;
  final List<Color>? gradientColors;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;
  final double shadowBlurRadius;
  final double shadowSpreadRadius;
  final Offset shadowOffset;
  final Color? shadowColor;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.blur = 20.0,
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,
    this.gradientColors,
    this.gradientBegin,
    this.gradientEnd,
    this.shadowBlurRadius = 30.0,
    this.shadowSpreadRadius = 0.0,
    this.shadowOffset = const Offset(0, 10),
    this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // ?쇱씠??紐⑤뱶: ?몃뵒怨??댄듃 ?뚮몢由?+ 洹몃┝?먮줈 移대뱶 援щ텇
    final borderClr = isDarkMode
        ? (gradientColors != null
                ? gradientColors!.first
                : (borderColor == Colors.white
                    ? theme.colorScheme.onSurface
                    : borderColor))
            .withValues(alpha: 0.1)
        : const Color(0xFFF3DECA); // Indigo 100 ???몃뵒怨????뚮몢由?

    final shadow = isDarkMode
        ? BoxShadow(
            color: shadowColor ?? Colors.black.withValues(alpha: 0.25),
            blurRadius: shadowBlurRadius,
            spreadRadius: shadowSpreadRadius,
            offset: shadowOffset,
          )
        : BoxShadow(
            color: shadowColor ?? const Color(0x0FD86B27), // Warm tint shadow
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          );

    // 諛곌꼍??寃곗젙
    // ?쇱씠??紐⑤뱶: 諛앹? ?됱씠硫??꾩＜ ?고븳 ?몃뵒怨??붿씠???곸슜
    final Color bgColor;
    if (isDarkMode) {
      // 다크 모드는 colorScheme.surfaceContainer 사용 (= AccentPalette 의 sharedSurface #383838)
      // 모든 GlassContainer 가 한 토큰으로 통일됨 → 다른 곳에서도 같은 토큰 쓰면 자동 일관성
      bgColor = theme.colorScheme.surfaceContainer;
    } else {
      if (gradientColors != null) {
        final baseColor = gradientColors!.first.withAlpha(255);
        final lum = baseColor.computeLuminance();
        bgColor = lum > 0.7 ? const Color(0xFFFCFCFF) : gradientColors!.first; // ?몃뵒怨??댄듃 ?붿씠??
      } else {
        bgColor = const Color(0xFFFCFCFF); // ?쒕갚 ????꾩＜ 誘몄꽭???몃뵒怨??붿씠??
      }
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: bgColor,
        border: Border.all(
          color: borderClr,
          width: borderWidth,
        ),
        boxShadow: [shadow],
      ),
      // 다크/라이트 모두 평평한 단색 (BackdropFilter 제거 — 통일성 확보)
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          child: child,
        ),
      ),
    );
    /* legacy block removed
    return Container(
      child: isDarkMode
          // ?ㅽ겕 紐⑤뱶: 釉붾윭 ?④낵 ?좎?
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: Container(
                  padding: padding,
                  decoration: BoxDecoration(
                    color: bgColor,
                  ),
                  child: child,
                ),
              ),
            )
          // ?쇱씠??紐⑤뱶: 釉붾윭 ?쒓굅, 源붾걫???붾━??移대뱶
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding,
                child: child,
              ),
            ),
    );
    */
  }
}

/// 입력 필드 위젯
class GlassTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final TextInputType? keyboardType;
  final void Function(String)? onFieldSubmitted;

  const GlassTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.keyboardType,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 15.0,
      blur: 20.0,
      borderWidth: 1.0,
      // 다크 모드는 GlassContainer 내부에서 colorScheme.surfaceContainer 사용 (이 값 무시됨)
      gradientColors: isDarkMode ? null : [Colors.white],
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF3C2A1A),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF64748B),
                  ),
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF64748B),
                  ),
                  child: suffixIcon!,
                )
              : null,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF475569).withValues(alpha: 0.8),
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white.withValues(alpha: 0.5) : const Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }
}

/// 踰꾪듉 ?꾩젽
class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final List<Color>? gradientColors;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.gradientColors,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;
    // 다크 모드는 GlassContainer 와 동일한 surface 토큰 사용 (모든 표면 통일)
    final darkDefault = cs.surfaceContainer;
    final darkHover = cs.surfaceContainerHigh;

    final defaultColor = widget.gradientColors != null
        ? (isDarkMode ? darkDefault : widget.gradientColors!.first)
        : isDarkMode
            ? darkDefault
            : Colors.white;

    final hoverColor = widget.gradientColors != null
        ? (isDarkMode ? darkHover : widget.gradientColors!.first.withValues(alpha:
            (widget.gradientColors!.first.a + 0.2).clamp(0.0, 1.0),
          ))
        : isDarkMode
            ? darkHover
            : const Color(0xFFFFF3E6); // Indigo 50 hover

    return GlassContainer(
      width: widget.width,
      padding: EdgeInsets.zero,
      borderRadius: 15.0,
      blur: 20.0,
      borderWidth: 1.0,
      gradientColors: [_isHovered ? hoverColor : defaultColor],
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          cursor: widget.isLoading ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          onEnter: (_) {
            if (!widget.isLoading && widget.onPressed != null) {
              setState(() {
                _isHovered = true;
              });
            }
          },
          onExit: (_) {
            setState(() {
              _isHovered = false;
            });
          },
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(15.0),
            splashColor: widget.gradientColors != null
              ? Colors.white.withValues(alpha: 0.3)
              : Colors.black.withValues(alpha: 0.1),
            highlightColor: widget.gradientColors != null
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.05),
            child: Container(
              width: widget.width ?? double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.text,
                      style: TextStyle(
                        color: widget.gradientColors != null
                          ? Colors.white
                          : const Color(0xFF3C2A1A),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

