import 'dart:ui';
import 'package:flutter/material.dart';

/// Liquid Glass 스타일의 반투명 컨테이너 위젯
/// 
/// 특징:
/// - 배경 블러 효과
/// - 반투명 배경
/// - 미묘한 테두리
/// - 부드러운 그림자
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

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.blur = 20.0,  // 더 강한 블러 효과
    this.borderColor = Colors.white,
    this.borderWidth = 1.0,  // 더 미묘한 테두리
    this.gradientColors,
    this.gradientBegin,
    this.gradientEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (gradientColors != null 
            ? gradientColors!.first 
            : Colors.white).withOpacity(0.6),  // 밝은 배경에 맞게 테두리
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.1),  // Material shadow 색상
            blurRadius: 30,
            spreadRadius: 0,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: gradientColors != null
                  ? LinearGradient(
                      begin: gradientBegin ?? Alignment.topLeft,
                      end: gradientEnd ?? Alignment.bottomRight,
                      colors: gradientColors!,
                    )
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.4),  // 밝은 흰색 배경에 맞게
                        Colors.white.withOpacity(0.3),  // 밝은 흰색 배경에 맞게
                      ],
                    ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass 스타일의 입력 필드
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
  final void Function(String)? onFieldSubmitted;  // 엔터 키 처리

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
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 15.0,
      blur: 20.0,  // 더 강한 블러
      borderWidth: 0.8,  // 더 미묘한 테두리
      gradientColors: [
        Colors.white.withOpacity(0.5),  // 밝은 배경에 맞게 더 밝게
        Colors.white.withOpacity(0.4),  // 밝은 배경에 맞게 더 밝게
      ],
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onFieldSubmitted: onFieldSubmitted,  // 엔터 키 처리
        validator: validator,
        style: TextStyle(
          color: const Color(0xFF1F2937),  // 밝은 배경에 맞게 어두운 텍스트
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null
              ? IconTheme(
                  data: const IconThemeData(color: Color(0xFF6B7280)),  // 밝은 배경에 맞게 어두운 아이콘
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconTheme(
                  data: const IconThemeData(color: Color(0xFF6B7280)),  // 밝은 배경에 맞게 어두운 아이콘
                  child: suffixIcon!,
                )
              : null,
          labelStyle: TextStyle(
            color: const Color(0xFF4B5563).withOpacity(0.8),  // 밝은 배경에 맞게 어두운 텍스트
            fontWeight: FontWeight.w400,
          ),
          hintStyle: TextStyle(
            color: const Color(0xFF9CA3AF),  // 밝은 배경에 맞게 회색 텍스트
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

/// Liquid Glass 스타일의 버튼
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
    // 기본 그라데이션 색상
    final defaultGradient = widget.gradientColors ??
        [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.4),
        ];

    // 호버 시 그라데이션 색상 (더 진하게)
    final hoverGradient = widget.gradientColors != null
        ? [
            widget.gradientColors!.first.withOpacity(
              (widget.gradientColors!.first.opacity + 0.2).clamp(0.0, 1.0),  // 더 진하게 (최대 1.0)
            ),
            widget.gradientColors!.last.withOpacity(
              (widget.gradientColors!.last.opacity + 0.15).clamp(0.0, 1.0),  // 더 진하게 (최대 1.0)
            ),
          ]
        : [
            Colors.white.withOpacity(0.7),  // 호버 시 더 밝게
            Colors.white.withOpacity(0.6),  // 호버 시 더 밝게
          ];

    return GlassContainer(
      width: widget.width,
      padding: EdgeInsets.zero,  // 패딩 제거 (내부 Container에서 처리)
      borderRadius: 15.0,
      blur: 20.0,  // 더 강한 블러
      borderWidth: 1.0,  // 더 미묘한 테두리
      gradientColors: _isHovered ? hoverGradient : defaultGradient,
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
              ? Colors.white.withOpacity(0.3)  // 포인트 색상 버튼의 스플래시 효과
              : Colors.black.withOpacity(0.1),  // 기본 버튼의 스플래시 효과
            highlightColor: widget.gradientColors != null 
              ? Colors.white.withOpacity(0.2)  // 포인트 색상 버튼의 하이라이트 효과
              : Colors.black.withOpacity(0.05),  // 기본 버튼의 하이라이트 효과
            child: Container(
              width: widget.width ?? double.infinity,  // width가 지정되면 사용, 아니면 전체 너비
              padding: const EdgeInsets.symmetric(vertical: 16),  // 버튼 내부 패딩
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
                          ? Colors.white  // 포인트 색상 버튼은 흰색 텍스트
                          : const Color(0xFF1F2937),  // 기본 버튼은 어두운 텍스트
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

