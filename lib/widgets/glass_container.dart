import 'dart:ui';
import 'package:flutter/material.dart';

/// 카드 컨테이너 위젯
///
/// 라이트 모드: 순백 배경 + 미세 테두리 + 그림자 → 배경 대비 확실한 구분
/// 다크 모드: 어두운 배경 + 블러 효과
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

    // 라이트 모드: 인디고 틴트 테두리 + 그림자로 카드 구분
    final borderClr = isDarkMode
        ? (gradientColors != null
            ? gradientColors!.first
            : Colors.white).withOpacity(0.1)
        : const Color(0xFFE0E7FF); // Indigo 100 — 인디고 톤 테두리

    final shadow = isDarkMode
        ? BoxShadow(
            color: shadowColor ?? Colors.black.withOpacity(0.25),
            blurRadius: shadowBlurRadius,
            spreadRadius: shadowSpreadRadius,
            offset: shadowOffset,
          )
        : BoxShadow(
            color: shadowColor ?? const Color(0x0F4F46E5), // Indigo tint shadow
            blurRadius: 24,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          );

    // 배경색 결정
    // 라이트 모드: 밝은 색이면 아주 연한 인디고 화이트 적용
    final Color bgColor;
    if (isDarkMode) {
      bgColor = gradientColors != null
          ? const Color(0xFF161B2E)
          : const Color(0xFF0F1219);
    } else {
      if (gradientColors != null) {
        final baseColor = gradientColors!.first.withAlpha(255);
        final lum = baseColor.computeLuminance();
        bgColor = lum > 0.7 ? const Color(0xFFFCFCFF) : gradientColors!.first; // 인디고 틴트 화이트
      } else {
        bgColor = const Color(0xFFFCFCFF); // 순백 대신 아주 미세한 인디고 화이트
      }
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: isDarkMode ? null : bgColor,
        border: Border.all(
          color: borderClr,
          width: borderWidth,
        ),
        boxShadow: [shadow],
      ),
      child: isDarkMode
          // 다크 모드: 블러 효과 유지
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
          // 라이트 모드: 블러 제거, 깔끔한 솔리드 카드
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding,
                child: child,
              ),
            ),
    );
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
      gradientColors: [
        isDarkMode
            ? const Color(0xFF0F1219)
            : Colors.white,
      ],
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: TextStyle(
          color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                  ),
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                    color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF64748B),
                  ),
                  child: suffixIcon!,
                )
              : null,
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.7) : const Color(0xFF475569).withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.white.withOpacity(0.5) : const Color(0xFF94A3B8),
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

/// 버튼 위젯
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

    final defaultColor = widget.gradientColors != null
        ? (isDarkMode ? const Color(0xFF0F1219) : widget.gradientColors!.first)
        : isDarkMode
            ? const Color(0xFF0F1219)
            : Colors.white;

    final hoverColor = widget.gradientColors != null
        ? (isDarkMode ? const Color(0xFF0B0E14) : widget.gradientColors!.first.withOpacity(
            (widget.gradientColors!.first.opacity + 0.2).clamp(0.0, 1.0),
          ))
        : isDarkMode
            ? const Color(0xFF0B0E14)
            : const Color(0xFFEEF2FF); // Indigo 50 hover

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
              ? Colors.white.withOpacity(0.3)
              : Colors.black.withOpacity(0.1),
            highlightColor: widget.gradientColors != null
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.05),
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
                          : const Color(0xFF0F172A),
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
