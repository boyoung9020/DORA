import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Google "G" official multicolor logo SVG
const _googleSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>
''';

// Kakao speech-bubble official logo SVG (black)
const _kakaoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">
  <path d="M12 3C6.48 3 2 6.69 2 11.25c0 2.9 1.67 5.45 4.21 7.04L5.25 21.5l4.09-2.18c.87.17 1.76.26 2.66.26 5.52 0 10-3.69 10-8.25S17.52 3 12 3z" fill="#000000"/>
</svg>
''';

enum SocialProvider { google, kakao }

class SocialLoginButton extends StatelessWidget {
  final SocialProvider provider;
  final String label;
  final VoidCallback? onPressed;

  const SocialLoginButton({
    super.key,
    required this.provider,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isGoogle = provider == SocialProvider.google;

    final background = isGoogle ? Colors.white : const Color(0xFFFEE500);
    final foreground =
        isGoogle ? const Color(0xFF191919) : const Color(0xFF191919);
    final borderColor =
        isGoogle ? const Color(0xFFE4C8AD) : const Color(0xFFE0CF4D);

    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(
              isGoogle ? _googleSvg : _kakaoSvg,
              width: 18,
              height: 18,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
