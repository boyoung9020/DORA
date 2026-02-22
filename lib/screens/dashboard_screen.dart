import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import 'admin_approval_screen.dart';
import 'task_detail_screen.dart';

/// ??쒕낫???붾㈃ - ???붾㈃
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<User>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = AuthService().getAllUsers();
    // ?붾㈃ 濡쒕뱶 ???쒖뒪??遺덈윭?ㅺ린
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  /// ?ㅻ뒛 ?????꾪꽣留?(紐⑤뱺 ?꾨줈?앺듃) - In review? In progress留? ?꾩옱 ?ъ슜?먯뿉寃??좊떦??寃껊쭔
  List<Task> _getTodayTasks(List<Task> allTasks, String? currentUserId) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return allTasks.where((task) {
      // ?꾩옱 ?ъ슜?먯뿉寃??좊떦???쒖뒪?щ쭔 ?꾪꽣留?
      if (currentUserId == null || !task.assignedMemberIds.contains(currentUserId)) {
        return false;
      }
      
      // In review ?먮뒗 In progress ?곹깭留??꾪꽣留?
      if (task.status != TaskStatus.inReview && task.status != TaskStatus.inProgress) {
        return false;
      }
      
      // ?쒖옉?쇱씠 ?덉쑝硫??쒖옉??湲곗?, ?놁쑝硫??앹꽦??湲곗?
      final startDate = task.startDate;
      final endDate = task.endDate;
      
      // 鍮꾧탳???좎쭨 寃곗젙: ?쒖옉?쇱씠 ?덉쑝硫??쒖옉?? ?놁쑝硫??앹꽦??
      DateTime dateToCheck;
      if (startDate != null) {
        dateToCheck = DateTime(startDate.year, startDate.month, startDate.day);
      } else {
        dateToCheck = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
      }
      
      // ?좎쭨媛 ?ㅻ뒛??寃쎌슦
      if (dateToCheck.isAtSameMomentAs(todayStart)) {
        return true;
      }
      
      // ?쒖옉?쇨낵 醫낅즺?쇱씠 紐⑤몢 ?덇퀬, ?ㅻ뒛??洹??ъ씠???덈뒗 寃쎌슦
      if (startDate != null && endDate != null) {
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return (todayStart.isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
                todayStart.isBefore(endDateOnly.add(const Duration(days: 1))));
      }
      
      return false;
    }).toList();
  }

  /// ?좎쭨 ?щ㎎??
  String _formatDate(DateTime date) {
    final months = [
      '1월',
      '2월',
      '3월',
      '4월',
      '5월',
      '6월',
      '7월',
      '8월',
      '9월',
      '10월',
      '11월',
      '12월',
    ];
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${months[date.month - 1]} ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  /// ?꾨줈?앺듃蹂??ㅻ뒛 ????洹몃９??
  Map<String, List<Task>> _getTodayTasksByProject(List<Task> allTasks, List<Project> projects, String? currentUserId) {
    final todayTasks = _getTodayTasks(allTasks, currentUserId);
    final Map<String, List<Task>> tasksByProject = {};
    
    for (final project in projects) {
      tasksByProject[project.id] = todayTasks.where((task) => task.projectId == project.id).toList();
    }
    
    return tasksByProject;
  }

  /// ?꾨줈?앺듃蹂?吏꾪뻾瑜?怨꾩궛
  double _calculateProgress(Project project, List<Task> allTasks) {
    final projectTasks = allTasks.where((task) => task.projectId == project.id).toList();
    if (projectTasks.isEmpty) return 0.0;
    
    final doneTasks = projectTasks.where((task) => task.status == TaskStatus.done).length;
    return doneTasks / projectTasks.length;
  }

  /// ?꾨줈?앺듃蹂??쒖뒪??媛쒖닔
  Map<String, int> _getTaskCountsByProject(List<Task> allTasks) {
    final Map<String, int> counts = {};
    for (final task in allTasks) {
      counts[task.projectId] = (counts[task.projectId] ?? 0) + 1;
    }
    return counts;
  }

  /// ?쒓컙?蹂??몄궗 硫붿떆吏 諛섑솚
  String _getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return '좋은 아침입니다';
    } else if (hour >= 12 && hour < 17) {
      return '좋은 오후입니다';
    } else if (hour >= 17 && hour < 22) {
      return '좋은 저녁입니다';
    } else {
      return '안녕하세요';
    }
  }

  Map<TaskStatus, int> _getStatusCounts(List<Task> tasks) {
    final counts = <TaskStatus, int>{
      TaskStatus.backlog: 0,
      TaskStatus.ready: 0,
      TaskStatus.inProgress: 0,
      TaskStatus.inReview: 0,
      TaskStatus.done: 0,
    };
    for (final task in tasks) {
      counts[task.status] = (counts[task.status] ?? 0) + 1;
    }
    return counts;
  }

  List<MapEntry<String, int>> _buildWorkload(
    List<Task> tasks,
    List<User> users,
  ) {
    final usernameById = {for (final u in users) u.id: u.username};
    final counts = <String, int>{};
    for (final task in tasks) {
      for (final uid in task.assignedMemberIds) {
        counts[uid] = (counts[uid] ?? 0) + 1;
      }
    }

    final result = counts.entries
        .map((e) => MapEntry(usernameById[e.key] ?? e.key, e.value))
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return result.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final user = authProvider.currentUser;
    final allProjects = projectProvider.projects;
    final allTasks = taskProvider.tasks;
    final statusCounts = _getStatusCounts(allTasks);
    final totalTaskCount = allTasks.length;

    // 紐⑤뱺 ?꾨줈?앺듃???ㅻ뒛 ?????꾪꽣留?
    final todayTasks = _getTodayTasks(allTasks, user?.id);
    // ?꾨줈?앺듃蹂??ㅻ뒛 ????洹몃９??
    final todayTasksByProject = _getTodayTasksByProject(allTasks, allProjects, user?.id);

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ?ㅻ뜑 (?좎쭨 + ?섏쁺 硫붿떆吏 + 愿由ъ옄 踰꾪듉)
          Stack(
            children: [
              // ?몄궭留?(吏꾩쭨 以묒븰)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getGreetingMessage()}, ',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      "${user?.username ?? '사용자'}님",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (authProvider.isAdmin) ...[
                      const SizedBox(width: 12),
                      GlassContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        borderRadius: 12.0,
                        blur: 15.0,
                        gradientColors: [
                          colorScheme.primary.withValues(alpha: 0.3),
                          colorScheme.primary.withValues(alpha: 0.2),
                        ],
                        borderColor: colorScheme.primary.withValues(alpha: 0.5),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.admin_panel_settings,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '관리자',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ?ㅻ뒛 ?좎쭨 (媛???쇱そ)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              // 愿由ъ옄 ?섏씠吏 踰꾪듉 (?ㅻⅨ履?
              if (authProvider.isAdmin)
                Align(
                  alignment: Alignment.centerRight,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 12.0,
                    blur: 20.0,
                    gradientColors: [
                      colorScheme.primary.withValues(alpha: 0.3),
                      colorScheme.primary.withValues(alpha: 0.2),
                    ],
                    child: IconButton(
                      icon: Icon(
                        Icons.admin_panel_settings,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        // 愿由ъ옄 ?섏씠吏瑜??ㅼ씠?쇰줈洹몃줈 ?쒖떆
                        showDialog(
                          context: context,
                          builder: (context) => const AdminApprovalScreen(),
                        );
                      },
                      tooltip: '관리자 페이지',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          // 硫붿씤 而⑦뀗痢?(2???덉씠?꾩썐)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ?쇱そ: ?ㅻ뒛 ????(紐⑤뱺 ?꾨줈?앺듃 醫낇빀)
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // ?ㅻ뜑
                  Row(
                    children: [
                      Icon(
                        Icons.today,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '오늘 할 일',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${todayTasks.length}개',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ?ㅻ뒛 ????紐⑸줉 (?꾨줈?앺듃蹂꾨줈 洹몃９??
                  todayTasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '오늘 할 일이 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...allProjects.where((project) {
                              final projectTasks = todayTasksByProject[project.id] ?? [];
                              return projectTasks.isNotEmpty;
                            }).map((project) {
                            final projectTasks = todayTasksByProject[project.id] ?? [];
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: GlassContainer(
                                padding: const EdgeInsets.all(20),
                                borderRadius: 15.0,
                                blur: 20.0,
                                gradientColors: [
                                  colorScheme.surface.withValues(alpha: 0.5),
                                  colorScheme.surface.withValues(alpha: 0.4),
                                ],
                                borderColor: project.color.withValues(alpha: 0.4),
                                borderWidth: 1.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ?꾨줈?앺듃 ?ㅻ뜑
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: project.color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          project.name,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: colorScheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: project.color.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${projectTasks.length}개',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: project.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // ?꾨줈?앺듃蹂??쒖뒪??紐⑸줉
                                    ...projectTasks.map((task) {
                                      final statusColor = task.status.color;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: InkWell(
                                          onTap: () {
                                            showGeneralDialog(
                                              context: context,
                                              transitionDuration: Duration.zero,
                                              pageBuilder: (context, animation, secondaryAnimation) => TaskDetailScreen(task: task),
                                              transitionBuilder: (context, animation, secondaryAnimation, child) => child,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: GlassContainer(
                                            padding: const EdgeInsets.all(16),
                                            borderRadius: 12.0,
                                            blur: 15.0,
                                            borderWidth: 1.0,
                                            gradientColors: [
                                              colorScheme.surface.withValues(alpha: 0.6),
                                              colorScheme.surface.withValues(alpha: 0.5),
                                            ],
                                            borderColor: statusColor.withValues(alpha: 0.3),
                                            child: Row(
                                            children: [
                                              // ?곹깭 ?됱긽 ?몃뵒耳?댄꽣
                                              Container(
                                                width: 4,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // ?쒖뒪???댁슜
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      task.title,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    if (task.description.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        task.description,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: colorScheme.onSurface.withValues(alpha: 0.7),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    // ?좊떦??????쒓렇
                                                    if (task.assignedMemberIds.isNotEmpty) ...[
                                                      const SizedBox(height: 8),
                                                      FutureBuilder<List<dynamic>>(
                                                        future: _loadAssignedMembers(task.assignedMemberIds),
                                                        builder: (context, snapshot) {
                                                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                                            return const SizedBox.shrink();
                                                          }
                                                          final members = snapshot.data!;
                                                          return Wrap(
                                                            spacing: 4,
                                                            runSpacing: 4,
                                                            children: members.map((member) {
                                                              return GlassContainer(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                borderRadius: 6.0,
                                                                blur: 10.0,
                                                                gradientColors: [
                                                                  colorScheme.primary.withValues(alpha: 0.2),
                                                                  colorScheme.primary.withValues(alpha: 0.1),
                                                                ],
                                                                borderColor: colorScheme.primary.withValues(alpha: 0.3),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    CircleAvatar(
                                                                      radius: 6,
                                                                      backgroundColor: AvatarColor.getColorForUser(member.id),
                                                                      child: Text(
                                                                    AvatarColor.getInitial(member.username),
                                                                    style: const TextStyle(
                                                                          fontSize: 8,
                                                                          color: Colors.white,
                                                                          fontWeight: FontWeight.bold,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(width: 4),
                                                                    Text(
                                                                      member.username,
                                                                      style: TextStyle(
                                                                        fontSize: 10,
                                                                        color: colorScheme.onSurface,
                                                                        fontWeight: FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );
                                                            }).toList(),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // ?곹깭 諛곗?
                                              GlassContainer(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                borderRadius: 12.0,
                                                blur: 15.0,
                                                gradientColors: [
                                                  statusColor.withValues(alpha: 0.3),
                                                  statusColor.withValues(alpha: 0.2),
                                                ],
                                                borderColor: statusColor.withValues(alpha: 0.5),
                                                child: Text(
                                                  task.status.displayName,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.people_alt_outlined,
                                color: colorScheme.primary,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '팀원별 워크로드',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<User>>(
                            future: _usersFuture,
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }

                              final workload = _buildWorkload(allTasks, snapshot.data!);
                              if (workload.isEmpty) {
                                return GlassContainer(
                                  padding: const EdgeInsets.all(16),
                                  borderRadius: 14.0,
                                  blur: 18.0,
                                  gradientColors: [
                                    colorScheme.surface.withValues(alpha: 0.5),
                                    colorScheme.surface.withValues(alpha: 0.4),
                                  ],
                                  child: Text(
                                    '담당자가 지정된 태스크가 없습니다',
                                    style: TextStyle(
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                );
                              }

                              final maxCount = workload.first.value;
                              return GlassContainer(
                                padding: const EdgeInsets.all(16),
                                borderRadius: 14.0,
                                blur: 18.0,
                                gradientColors: [
                                  colorScheme.surface.withValues(alpha: 0.5),
                                  colorScheme.surface.withValues(alpha: 0.4),
                                ],
                                child: Column(
                                  children: workload.map((entry) {
                                    final ratio = maxCount == 0 ? 0.0 : entry.value / maxCount;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AvatarColor.getColorForUser(entry.key),
                                            child: Text(
                                              AvatarColor.getInitial(entry.key),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        entry.key,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: colorScheme.onSurface,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${entry.value}개',
                                                      style: TextStyle(
                                                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: LinearProgressIndicator(
                                                    value: ratio,
                                                    minHeight: 6,
                                                    backgroundColor: colorScheme.primary.withValues(alpha: 0.12),
                                                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // ?몃줈 援щ텇??
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: const Color(0xFFF3DECA),
                ),
                // ?ㅻⅨ履? ?꾨줈?앺듃蹂?吏꾪뻾瑜?
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // ?ㅻ뜑
                  Row(
                    children: [
                      Icon(
                        Icons.assessment,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '프로젝트 진행률',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ?꾨줈?앺듃蹂?吏꾪뻾瑜?移대뱶
                  if (allProjects.isEmpty)
                    GlassContainer(
                      padding: const EdgeInsets.all(40),
                      borderRadius: 20.0,
                      blur: 25.0,
                      gradientColors: [
                        colorScheme.surface.withValues(alpha: 0.4),
                        colorScheme.surface.withValues(alpha: 0.3),
                      ],
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 48,
                              color: colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '프로젝트가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...allProjects.map((project) {
                      final progress = _calculateProgress(project, allTasks);
                      final taskCounts = _getTaskCountsByProject(allTasks);
                      final taskCount = taskCounts[project.id] ?? 0;
                      final doneCount = allTasks
                          .where((task) =>
                              task.projectId == project.id &&
                              task.status == TaskStatus.done)
                          .length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GlassContainer(
                          padding: const EdgeInsets.all(20),
                          borderRadius: 20.0,
                          blur: 25.0,
                          borderWidth: 1.0,
                          gradientColors: [
                            colorScheme.surface.withValues(alpha: 0.4),
                            colorScheme.surface.withValues(alpha: 0.3),
                          ],
                          borderColor: project.color.withValues(alpha: 0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ?꾨줈?앺듃 ?ㅻ뜑
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: project.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      project.name,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}%',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: project.color,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // 吏꾪뻾瑜?諛?
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFFF3DECA),
                                  valueColor: AlwaysStoppedAnimation<Color>(project.color),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // ?쒖뒪???듦퀎
                              Row(
                                children: [
                                  Icon(
                                    Icons.task,
                                    size: 16,
                                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '전체: $taskCount개',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: TaskStatus.done.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '완료: $doneCount개',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Icon(
                          Icons.stacked_bar_chart_outlined,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '상태별 태스크 통계',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    GlassContainer(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 14.0,
                      blur: 18.0,
                      gradientColors: [
                        colorScheme.surface.withValues(alpha: 0.45),
                        colorScheme.surface.withValues(alpha: 0.35),
                      ],
                      child: Column(
                        children: [
                          TaskStatus.backlog,
                          TaskStatus.ready,
                          TaskStatus.inProgress,
                          TaskStatus.inReview,
                          TaskStatus.done,
                        ].map((status) {
                          final count = statusCounts[status] ?? 0;
                          final ratio = totalTaskCount == 0 ? 0.0 : count / totalTaskCount;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: status.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        status.displayName,
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$count',
                                      style: TextStyle(
                                        color: colorScheme.onSurface.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: ratio,
                                    minHeight: 6,
                                    backgroundColor: status.color.withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(status.color),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ?좊떦?????紐⑸줉 濡쒕뱶
  Future<List<dynamic>> _loadAssignedMembers(List<String> memberIds) async {
    try {
      final authService = AuthService();
      final allUsers = await authService.getAllUsers();
      return allUsers.where((user) => memberIds.contains(user.id)).toList();
    } catch (e) {
      return [];
    }
  }
}

