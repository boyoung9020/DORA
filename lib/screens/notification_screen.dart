import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../models/notification.dart' as app_notification;
import '../widgets/glass_container.dart';
import 'task_detail_screen.dart';

/// 알림 화면
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  app_notification.NotificationType? _selectedFilter;

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

  /// 상대 시간 포맷팅 (Slack/GitHub 스타일)
  String _formatRelativeTime(DateTime date) {
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
      return '${weeks}주 전';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '${months}개월 전';
    } else {
      final years = (diff.inDays / 365).floor();
      return '${years}년 전';
    }
  }

  /// 날짜별 그룹 라벨 가져오기
  String _getDateGroupLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final notificationDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(notificationDate).inDays;

    if (diff == 0) {
      return '오늘';
    } else if (diff == 1) {
      return '어제';
    } else if (diff <= 7) {
      return '이번 주';
    } else if (diff <= 30) {
      return '이번 달';
    } else {
      return '이전';
    }
  }

  /// 필터 칩 빌더
  Widget _buildFilterChip(app_notification.NotificationType? type, String label, IconData icon, ColorScheme colorScheme) {
    final isSelected = _selectedFilter == type;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSelected ? Colors.white : colorScheme.onSurface.withOpacity(0.6)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : colorScheme.onSurface.withOpacity(0.7))),
        ],
      ),
      selectedColor: colorScheme.primary,
      backgroundColor: colorScheme.surface,
      side: BorderSide(color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      onSelected: (_) {
        setState(() {
          _selectedFilter = isSelected ? null : type;
        });
      },
    );
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
        return const Color(0xFF4F46E5); // 인디고
      case app_notification.NotificationType.taskAssigned:
        return const Color(0xFFF59E0B); // 앰버
      case app_notification.NotificationType.taskOptionChanged:
        return const Color(0xFF8B5CF6); // 바이올렛
      case app_notification.NotificationType.taskCommentAdded:
        return const Color(0xFF10B981); // 에메랄드
    }
  }

  /// 알림 클릭 시 해당 항목으로 네비게이션
  void _handleNotificationTap(app_notification.Notification notification) async {
    final notificationProvider = context.read<NotificationProvider>();
    
    // 읽음 표시
    if (!notification.isRead) {
      await notificationProvider.markAsRead(notification.id);
    }

    // taskId가 있으면 TaskDetailScreen으로 이동
    if (notification.taskId != null && mounted) {
      final taskProvider = context.read<TaskProvider>();
      try {
        final task = taskProvider.tasks.firstWhere((t) => t.id == notification.taskId);
        if (mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.2),
            builder: (context) => TaskDetailScreen(task: task),
          );
        }
      } catch (e) {
        // 태스크를 찾을 수 없는 경우
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('해당 작업을 찾을 수 없습니다'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  /// 그룹핑된 알림 목록 빌드
  List<Widget> _buildGroupedNotificationList(
    List<app_notification.Notification> notifications,
    ColorScheme colorScheme,
    NotificationProvider notificationProvider,
    AuthProvider authProvider,
  ) {
    final widgets = <Widget>[];
    String? currentGroup;

    for (final notification in notifications) {
      final group = _getDateGroupLabel(notification.createdAt);

      // 새 그룹 헤더 추가
      if (group != currentGroup) {
        currentGroup = group;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    group,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: colorScheme.outline.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // 알림 카드 추가
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildNotificationCard(
            context,
            notification,
            colorScheme,
            notificationProvider,
            authProvider,
          ),
        ),
      );
    }

    return widgets;
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
              Row(
                children: [
                  Text(
                    '알림',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  if (notificationProvider.unreadCount > 0) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${notificationProvider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
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
          const SizedBox(height: 8),
          // 필터 칩
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(null, '전체', Icons.notifications_none, colorScheme),
                const SizedBox(width: 8),
                _buildFilterChip(app_notification.NotificationType.taskAssigned, '태스크 배정', Icons.assignment_ind, colorScheme),
                const SizedBox(width: 8),
                _buildFilterChip(app_notification.NotificationType.taskCommentAdded, '댓글', Icons.comment, colorScheme),
                const SizedBox(width: 8),
                _buildFilterChip(app_notification.NotificationType.taskOptionChanged, '옵션 변경', Icons.settings, colorScheme),
                const SizedBox(width: 8),
                _buildFilterChip(app_notification.NotificationType.projectMemberAdded, '멤버 추가', Icons.group_add, colorScheme),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_none,
                                size: 40,
                                color: colorScheme.primary.withOpacity(0.4),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              '알림이 없습니다',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '새로운 알림이 도착하면 여기에 표시됩니다',
                              style: TextStyle(
                                fontSize: 14,
                                color: colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                        child: Builder(builder: (context) {
                          final filtered = _selectedFilter == null
                              ? notificationProvider.notifications
                              : notificationProvider.notifications
                                  .where((n) => n.type == _selectedFilter)
                                  .toList();
                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                '해당 유형의 알림이 없습니다',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                                ),
                              ),
                            );
                          }
                          return ListView(
                            children: _buildGroupedNotificationList(
                              filtered,
                              colorScheme,
                              notificationProvider,
                              authProvider,
                            ),
                          );
                        }),
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
    final hasNavigation = notification.taskId != null;

    return GlassContainer(
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 읽지 않은 표시 (왼쪽 도트)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 20, right: 8),
                decoration: BoxDecoration(
                  color: isRead ? Colors.transparent : colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
              // 아이콘
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // 내용
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        // 시간 표시
                        Text(
                          _formatRelativeTime(notification.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // 메시지
                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // 하단 정보 (타입 + 네비게이션 힌트)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
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
                        if (hasNavigation) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: colorScheme.primary.withOpacity(0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '클릭하여 이동',
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.primary.withOpacity(0.5),
                            ),
                          ),
                        ],
                        const Spacer(),
                        // 삭제 버튼
                        InkWell(
                          onTap: () async {
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
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
