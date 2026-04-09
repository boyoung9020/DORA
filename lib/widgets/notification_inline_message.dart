import 'package:flutter/material.dart';
import '../models/notification.dart' as app_notification;
import '../models/task.dart';

/// 알림 본문: 인물·작업명(따옴표)·변경 필드 강조, 상태 전환은 [TaskStatus] 색 칩.
/// 알림 탭·대시보드 최근 활동 등에서 공통 사용.
class NotificationInlineMessage extends StatelessWidget {
  final app_notification.Notification notification;
  final ColorScheme colorScheme;
  final double bodyFontSize;
  final double typeTagFontSize;
  final int maxLines;
  /// false이면 ` · 유형명` 접미사 생략 (필요 시)
  final bool showTypeSuffix;

  const NotificationInlineMessage({
    super.key,
    required this.notification,
    required this.colorScheme,
    this.bodyFontSize = 13,
    this.typeTagFontSize = 12,
    this.maxLines = 3,
    this.showTypeSuffix = true,
  });

  static final RegExp _statusTransitionRe =
      RegExp(r'상태를 (.+?)에서 (.+?)으로');

  static TaskStatus? _taskStatusFromKoLabel(String raw) {
    final label = raw.trim();
    for (final s in TaskStatus.values) {
      if (s.displayName == label) return s;
    }
    return null;
  }

  static WidgetSpan _statusChipSpan(
    String label,
    TextStyle baseStyle,
    double chipFontSize,
  ) {
    final status = _taskStatusFromKoLabel(label);
    final chipColor = status?.color ?? const Color(0xFF6B7280);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: chipColor.withValues(alpha: 0.45),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            child: Text(
              label.trim(),
              style: baseStyle.copyWith(
                fontSize: chipFontSize,
                fontWeight: FontWeight.w700,
                color: chipColor,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static List<InlineSpan> _accentSpansForFragment(
    String fragment,
    TextStyle baseStyle,
    TextStyle personStyle,
    TextStyle quoteStyle,
    TextStyle fieldStyle, {
    required bool taskOptionFieldHighlight,
  }) {
    final spans = <InlineSpan>[];
    var pos = 0;
    final msg = fragment;

    while (pos < msg.length) {
      int? bestStart;
      int? bestEnd;
      TextStyle? bestStyle;

      void offer(int s, int e, TextStyle st) {
        if (s < pos || e <= s || s >= msg.length) return;
        if (bestStart == null || s < bestStart!) {
          bestStart = s;
          bestEnd = e;
          bestStyle = st;
        }
      }

      final rest = msg.substring(pos);
      final q = RegExp(r"'([^']+)'").firstMatch(rest);
      if (q != null) {
        offer(pos + q.start, pos + q.end, quoteStyle);
      }
      final p = RegExp(r'(.+?)님이').firstMatch(rest);
      if (p != null) {
        // 이름 부분만 색칠 (group(1): '양혜지'), '님이'는 제외
        final nameEnd = pos + p.start + p.group(1)!.length;
        offer(pos + p.start, nameEnd, personStyle);
      }
      if (taskOptionFieldHighlight) {
        final f = RegExp(r'작업의\s+(.+?)을\(를\)\s+변경').firstMatch(rest);
        if (f != null) {
          final g = f.group(1);
          if (g != null) {
            final i0 = f.start + f.group(0)!.indexOf(g);
            offer(pos + i0, pos + i0 + g.length, fieldStyle);
          }
        }
      }

      if (bestStart == null) {
        spans.add(TextSpan(text: msg.substring(pos), style: baseStyle));
        break;
      }
      if (bestStart! > pos) {
        spans.add(TextSpan(text: msg.substring(pos, bestStart!), style: baseStyle));
      }
      spans.add(TextSpan(
        text: msg.substring(bestStart!, bestEnd!),
        style: bestStyle!,
      ));
      pos = bestEnd!;
    }

    return spans;
  }

  List<InlineSpan> _buildSpans(double chipFontSize) {
    final baseStyle = TextStyle(
      fontSize: bodyFontSize,
      color: colorScheme.onSurfaceVariant,
      height: 1.38,
    );
    final personStyle = baseStyle.copyWith(
      color: const Color(0xFF6366F1),
      fontWeight: FontWeight.w700,
    );
    final quoteStyle = baseStyle.copyWith(
      color: const Color(0xFF0D9488),
      fontWeight: FontWeight.w700,
    );
    final fieldStyle = baseStyle.copyWith(
      color: const Color(0xFFE11D48),
      fontWeight: FontWeight.w700,
    );

    final msg = notification.message;
    final taskOption = notification.type ==
        app_notification.NotificationType.taskOptionChanged;
    final useStatusChips =
        taskOption && _statusTransitionRe.hasMatch(msg);

    final List<InlineSpan> spans;
    if (useStatusChips) {
      spans = [];
      var lastEnd = 0;
      for (final m in _statusTransitionRe.allMatches(msg)) {
        if (m.start > lastEnd) {
          spans.addAll(_accentSpansForFragment(
            msg.substring(lastEnd, m.start),
            baseStyle,
            personStyle,
            quoteStyle,
            fieldStyle,
            taskOptionFieldHighlight: taskOption,
          ));
        }
        final oldLabel = m.group(1);
        final newLabel = m.group(2);
        spans.add(TextSpan(text: '상태를 ', style: baseStyle));
        if (oldLabel != null) {
          spans.add(_statusChipSpan(oldLabel, baseStyle, chipFontSize));
        }
        spans.add(TextSpan(text: '에서 ', style: baseStyle));
        if (newLabel != null) {
          spans.add(_statusChipSpan(newLabel, baseStyle, chipFontSize));
        }
        spans.add(TextSpan(text: '으로', style: baseStyle));
        lastEnd = m.end;
      }
      if (lastEnd < msg.length) {
        spans.addAll(_accentSpansForFragment(
          msg.substring(lastEnd),
          baseStyle,
          personStyle,
          quoteStyle,
          fieldStyle,
          taskOptionFieldHighlight: taskOption,
        ));
      }
    } else {
      spans = _accentSpansForFragment(
        msg,
        baseStyle,
        personStyle,
        quoteStyle,
        fieldStyle,
        taskOptionFieldHighlight: taskOption,
      );
    }

    if (showTypeSuffix) {
      spans.add(TextSpan(
        text: '  · ${notification.type.displayName}',
        style: baseStyle.copyWith(
          fontSize: typeTagFontSize,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
          fontWeight: FontWeight.w500,
        ),
      ));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final chipFontSize = (bodyFontSize * 0.88).clamp(10.0, 11.5);
    return Text.rich(
      TextSpan(children: _buildSpans(chipFontSize)),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}
