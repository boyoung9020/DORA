import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/github.dart';
import '../../providers/github_provider.dart';
import '../../utils/tech_stack_devicon.dart';

/// 프로젝트 헤더 중앙 — GitHub 연결·언어 분석이 있을 때만 표시
class TechStackHeaderStrip extends StatelessWidget {
  final int maxIcons;

  const TechStackHeaderStrip({super.key, this.maxIcons = 10});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<GitHubProvider>(
      builder: (context, gh, _) {
        if (gh.connectedRepo == null) return const SizedBox.shrink();
        if (gh.languagesLoading && gh.languages.isEmpty) {
          return SizedBox(
            height: 34,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.primary.withValues(alpha: 0.65),
                ),
              ),
            ),
          );
        }
        if (gh.languages.isEmpty) return const SizedBox.shrink();

        final langs = gh.languages.take(maxIcons).toList();
        final extra = gh.languages.length - langs.length;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text(
              '기술 스택',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            ...langs.map(
              (l) => Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Tooltip(
                  message:
                      '${l.name} · ${l.percentage.toStringAsFixed(l.percentage >= 10 ? 0 : 1)}%',
                  child: _HeaderMiniLangIcon(language: l),
                ),
              ),
            ),
            if (extra > 0)
              Tooltip(
                message: gh.languages
                    .skip(maxIcons)
                    .map((e) =>
                        '${e.name} ${e.percentage.toStringAsFixed(e.percentage >= 10 ? 0 : 1)}%')
                    .join('\n'),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '+$extra',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HeaderMiniLangIcon extends StatelessWidget {
  final GitHubLanguage language;

  const _HeaderMiniLangIcon({required this.language});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = techStackLanguageColor(language.name);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: _TechLangIcon(
            languageName: language.name,
            accent: accent,
            compact: true,
          ),
        ),
      ),
    );
  }
}

class _TechLangIcon extends StatefulWidget {
  final String languageName;
  final Color accent;
  final bool compact;

  const _TechLangIcon({
    required this.languageName,
    required this.accent,
    this.compact = false,
  });

  @override
  State<_TechLangIcon> createState() => _TechLangIconState();
}

class _TechLangIconState extends State<_TechLangIcon> {
  late final Future<_SvgLoadResult> _load = _fetchSvg();

  Future<_SvgLoadResult> _fetchSvg() async {
    final url = techStackDeviconSvgUrl(widget.languageName);
    if (url == null) return _SvgLoadResult.fallback();
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200 || r.body.trim().isEmpty) {
        return _SvgLoadResult.fallback();
      }
      return _SvgLoadResult(utf8.decode(r.bodyBytes));
    } catch (_) {
      return _SvgLoadResult.fallback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_SvgLoadResult>(
      future: _load,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          final s = widget.compact ? 14.0 : 22.0;
          return Center(
            child: SizedBox(
              width: s,
              height: s,
              child: CircularProgressIndicator(
                strokeWidth: widget.compact ? 1.5 : 2,
                color: widget.accent.withValues(alpha: 0.6),
              ),
            ),
          );
        }
        final svg = snap.data?.svg;
        if (svg != null) {
          try {
            return SvgPicture.string(
              svg,
              fit: BoxFit.contain,
              allowDrawingOutsideViewBox: true,
            );
          } catch (_) {
            /* 일부 devicon SVG는 파서와 안 맞을 수 있음 */
          }
        }
        return _FallbackLangGlyph(
          name: widget.languageName,
          color: widget.accent,
          fontSize: widget.compact ? 11 : 17,
        );
      },
    );
  }
}

class _SvgLoadResult {
  final String? svg;

  _SvgLoadResult(this.svg);
  factory _SvgLoadResult.fallback() => _SvgLoadResult(null);
}

class _FallbackLangGlyph extends StatelessWidget {
  final String name;
  final Color color;
  final double fontSize;

  const _FallbackLangGlyph({
    required this.name,
    required this.color,
    this.fontSize = 17,
  });

  @override
  Widget build(BuildContext context) {
    final chars = name.trim().isEmpty
        ? '?'
        : (name.length >= 2 ? name.substring(0, 2) : name.substring(0, 1));
    final upper = chars.toUpperCase();
    return Center(
      child: Text(
        upper,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color.withValues(alpha: 0.92),
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
