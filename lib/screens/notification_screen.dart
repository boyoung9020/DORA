import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../models/notification.dart' as app_notification;
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';

/// 알림 화면
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 로드 시 알림 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      final notificationProvider = context.read<NotificationProvider>();
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        notificationProvider.loadNotifications(userId: authProvider.currentUser!.id);
      }
    });
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);

    if (notificationDate == today) {
      return '오늘 ${DateFormat('HH:mm').format(date)}';
    } else if (notificationDate == today.subtract(const Duration(days: 1))) {
      return '어제 ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('yyyy년 MM월 dd일 HH:mm').format(date);
    }
  }

  /// 알림 타입별 아이콘
  IconData _getNotificationIcon(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return Icons.group_add;
      case app_notification.NotificationType.taskAssigned:
        return Icons.assignment_ind;
      case app_notification.NotificationType.taskOptionChanged:
        return Icons.settings;
      case app_notification.NotificationType.taskCommentAdded:
        return Icons.comment;
    }
  }

  /// 알림 타입별 색상
  Color _getNotificationColor(app_notification.NotificationType type) {
    switch (type) {
      case app_notification.NotificationType.projectMemberAdded:
        return const Color(0xFF2196F3); // 파란색
      case app_notification.NotificationType.taskAssigned:
        return const Color(0xFFFF9800); // 주황색
      case app_notification.NotificationType.taskOptionChanged:
        return const Color(0xFF9C27B0); // 보라색
      case app_notification.NotificationType.taskCommentAdded:
        return const Color(0xFF4CAF50); // 초록색
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notificationProvider = context.watch<NotificationProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '알림',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  // 읽지 않은 알림 개수 표시
                  if (notificationProvider.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notificationProvider.unreadCount}개의 읽지 않은 알림',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  // 모두 읽음 표시 버튼
                  if (notificationProvider.unreadCount > 0)
                    TextButton.icon(
                      onPressed: () async {
                        if (authProvider.isAuthenticated && authProvider.currentUser != null) {
                          await notificationProvider.markAllAsRead(
                            userId: authProvider.currentUser!.id,
                          );
                        }
                      },
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('모두 읽음'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                      ),
                    ),
                  // 새로고침 버튼
                  IconButton(
                    onPressed: () {
                      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
                        notificationProvider.loadNotifications(
                          userId: authProvider.currentUser!.id,
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    tooltip: '새로고침',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 알림 목록
          Expanded(
            child: notificationProvider.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: colorScheme.primary,
                    ),
                  )
                : notificationProvider.notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '알림이 없습니다',
                              style: TextStyle(
                                fontSize: 18,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          if (authProvider.isAuthenticated && authProvider.currentUser != null) {
                            await notificationProvider.loadNotifications(
                              userId: authProvider.currentUser!.id,
                            );
                          }
                        },
                        color: colorScheme.primary,
                        child: ListView.separated(
                          itemCount: notificationProvider.notifications.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final notification = notificationProvider.notifications[index];
                            return _buildNotificationCard(
                              context,
                              notification,
                              colorScheme,
                              notificationProvider,
                              authProvider,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  /// 알림 카드 위젯
  Widget _buildNotificationCard(
    BuildContext context,
    app_notification.Notification notification,
    ColorScheme colorScheme,
    NotificationProvider notificationProvider,
    AuthProvider authProvider,
  ) {
    final isRead = notification.isRead;
    final iconColor = _getNotificationColor(notification.type);
    final icon = _getNotificationIcon(notification.type);

    return GlassContainer(
      child: InkWell(
        onTap: () async {
          // 알림 클릭 시 읽음 표시
          if (!notification.isRead) {
            await notificationProvider.markAsRead(notification.id);
          }
          // TODO: 알림 타입에 따라 해당 화면으로 이동
          // 예: taskId가 있으면 TaskDetailScreen으로 이동
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 아이콘
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목과 읽음 표시
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 메시지
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 날짜와 타입
                    Row(
                      children: [
                        Text(
                          _formatDate(notification.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            notification.type.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              color: iconColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // 삭제 버튼
              IconButton(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('알림 삭제'),
                      content: const Text('이 알림을 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('삭제'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await notificationProvider.deleteNotification(notification.id);
                  }
                },
                icon: const Icon(Icons.close, size: 20),
                color: colorScheme.onSurfaceVariant,
                tooltip: '삭제',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

