import 'package:flutter/material.dart';
import '../../models/notification.dart' as app_notification;
import '../notification_inline_message.dart';

/// 최근 활동 리스트의 단일 항목.
/// 대시보드 카드와 사이드 패널 양쪽에서 재사용한다.
class ActivityListItem extends StatelessWidget {
  final app_notification.Notification notification;
  final VoidCallback? onTap;
  /// true 이면 사이드 패널용 넓은 레이아웃
  final bool expanded;

  const ActivityListItem({
    super.key,
    required this.notification,
    this.onTap,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _getIcon(notification.type);
    final typeColor = _getColor(notification.type);
    final isUnread = !notification.isRead;

    final iconSize = expanded ? 36.0 : 32.0;
    final iconInner = expanded ? 18.0 : 16.0;
    final iconRadius = expanded ? 10.0 : 8.0;
    final titleSize = expanded ? 13.0 : 12.0;
    final msgSize = expanded ? 12.0 : 11.0;
    final timeSize = expanded ? 11.0 : 10.0;
    final dotSize = expanded ? 8.0 : 7.0;
    final hPad = expanded ? 16.0 : 4.0;
    final vPad = expanded ? 12.0 : 10.0;
    final maxLines = expanded ? 2 : 1;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: vPad, horizontal: hPad),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconSize,
              height: iconSize,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(iconRadius),
              ),
              child: Icon(icon, size: iconInner, color: typeColor),
            ),
            SizedBox(width: expanded ? 12 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: titleSize,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      color: cs.onSurface,
                    ),
                    maxLines: maxLines,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: expanded ? 3 : 2),
                  NotificationInlineMessage(
                    notification: notification,
                    colorScheme: cs,
                    bodyFontSize: msgSize,
                    typeTagFontSize: (msgSize - 0.5).clamp(10.0, 12.0),
                    maxLines: maxLines,
                    showTypeSuffix: true,
                  ),
                ],
              ),
            ),
            SizedBox(width: expanded ? 8 : 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRelativeTime(notification.createdAt),
                  style: TextStyle(
                    fontSize: timeSize,
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                if (isUnread) ...[
                  SizedBox(height: expanded ? 6 : 4),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 헬퍼 ──────────────────────────────────────────────────

  static IconData _getIcon(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return Icons.group_add;
      case app_notification.NotificationType.taskAssigned:
        return Icons.assignment_ind;
      case app_notification.NotificationType.taskCreated:
        return Icons.add_task;
      case app_notification.NotificationType.taskOptionChanged:
        return Icons.settings;
      case app_notification.NotificationType.taskCommentAdded:
        return Icons.comment;
      case app_notification.NotificationType.taskMentioned:
        return Icons.alternate_email;
    }
  }

  static Color _getColor(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return const Color(0xFF4F46E5);
      case app_notification.NotificationType.taskAssigned:
        return const Color(0xFFF59E0B);
      case app_notification.NotificationType.taskCreated:
        return const Color(0xFF059669);
      case app_notification.NotificationType.taskOptionChanged:
        return const Color(0xFF8B5CF6);
      case app_notification.NotificationType.taskCommentAdded:
        return const Color(0xFF10B981);
      case app_notification.NotificationType.taskMentioned:
        return const Color(0xFF2563EB);
    }
  }

  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return '방금 전';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}분 전';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}시간 전';
    } else if (diff.inDays < 2) {
      return '어제';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}일 전';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks주 전';
    } else {
      final months = (diff.inDays / 30).floor();
      return '$months개월 전';
    }
  }
}
