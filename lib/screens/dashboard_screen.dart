import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../models/task.dart';
import '../models/project.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import 'admin_approval_screen.dart';
import 'task_detail_screen.dart';

/// 대시보드 화면 - 홈 화면
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // 화면 로드 시 태스크 불러오기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
  }

  /// 오늘 할 일 필터링 (모든 프로젝트) - In review와 In progress만, 현재 사용자에게 할당된 것만
  List<Task> _getTodayTasks(List<Task> allTasks, String? currentUserId) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return allTasks.where((task) {
      // 현재 사용자에게 할당된 태스크만 필터링
      if (currentUserId == null || !task.assignedMemberIds.contains(currentUserId)) {
        return false;
      }
      
      // In review 또는 In progress 상태만 필터링
      if (task.status != TaskStatus.inReview && task.status != TaskStatus.inProgress) {
        return false;
      }
      
      // 시작일이 있으면 시작일 기준, 없으면 생성일 기준
      final startDate = task.startDate;
      final endDate = task.endDate;
      
      // 비교할 날짜 결정: 시작일이 있으면 시작일, 없으면 생성일
      DateTime dateToCheck;
      if (startDate != null) {
        dateToCheck = DateTime(startDate.year, startDate.month, startDate.day);
      } else {
        dateToCheck = DateTime(task.createdAt.year, task.createdAt.month, task.createdAt.day);
      }
      
      // 날짜가 오늘인 경우
      if (dateToCheck.isAtSameMomentAs(todayStart)) {
        return true;
      }
      
      // 시작일과 종료일이 모두 있고, 오늘이 그 사이에 있는 경우
      if (startDate != null && endDate != null) {
        final startDateOnly = DateTime(startDate.year, startDate.month, startDate.day);
        final endDateOnly = DateTime(endDate.year, endDate.month, endDate.day);
        return (todayStart.isAfter(startDateOnly.subtract(const Duration(days: 1))) &&
                todayStart.isBefore(endDateOnly.add(const Duration(days: 1))));
      }
      
      return false;
    }).toList();
  }

  /// 날짜 포맷팅
  String _formatDate(DateTime date) {
    final months = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월'];
    final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${date.year}년 ${months[date.month - 1]} ${date.day}일 (${weekdays[date.weekday - 1]})';
  }

  /// 프로젝트별 오늘 할 일 그룹화
  Map<String, List<Task>> _getTodayTasksByProject(List<Task> allTasks, List<Project> projects, String? currentUserId) {
    final todayTasks = _getTodayTasks(allTasks, currentUserId);
    final Map<String, List<Task>> tasksByProject = {};
    
    for (final project in projects) {
      tasksByProject[project.id] = todayTasks.where((task) => task.projectId == project.id).toList();
    }
    
    return tasksByProject;
  }

  /// 프로젝트별 진행률 계산
  double _calculateProgress(Project project, List<Task> allTasks) {
    final projectTasks = allTasks.where((task) => task.projectId == project.id).toList();
    if (projectTasks.isEmpty) return 0.0;
    
    final doneTasks = projectTasks.where((task) => task.status == TaskStatus.done).length;
    return doneTasks / projectTasks.length;
  }

  /// 프로젝트별 태스크 개수
  Map<String, int> _getTaskCountsByProject(List<Task> allTasks) {
    final Map<String, int> counts = {};
    for (final task in allTasks) {
      counts[task.projectId] = (counts[task.projectId] ?? 0) + 1;
    }
    return counts;
  }

  /// 시간대별 인사 메시지 반환
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final projectProvider = Provider.of<ProjectProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final user = authProvider.currentUser;
    final allProjects = projectProvider.projects;
    final allTasks = taskProvider.tasks;

    // 모든 프로젝트의 오늘 할 일 필터링
    final todayTasks = _getTodayTasks(allTasks, user?.id);
    // 프로젝트별 오늘 할 일 그룹화
    final todayTasksByProject = _getTodayTasksByProject(allTasks, allProjects, user?.id);

    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 (날짜 + 환영 메시지 + 관리자 버튼)
          Stack(
            children: [
              // 인삿말 (진짜 중앙)
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_getGreetingMessage()}, ',
                      style: TextStyle(
                        fontSize: 20,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    Text(
                      '${user?.username ?? '사용자'}님!',
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
                          colorScheme.primary.withOpacity(0.3),
                          colorScheme.primary.withOpacity(0.2),
                        ],
                        borderColor: colorScheme.primary.withOpacity(0.5),
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
              // 오늘 날짜 (가장 왼쪽)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatDate(DateTime.now()),
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ),
              // 관리자 페이지 버튼 (오른쪽)
              if (authProvider.isAdmin)
                Align(
                  alignment: Alignment.centerRight,
                  child: GlassContainer(
                    padding: EdgeInsets.zero,
                    borderRadius: 12.0,
                    blur: 20.0,
                    gradientColors: [
                      colorScheme.primary.withOpacity(0.3),
                      colorScheme.primary.withOpacity(0.2),
                    ],
                    child: IconButton(
                      icon: Icon(
                        Icons.admin_panel_settings,
                        color: colorScheme.primary,
                        size: 24,
                      ),
                      onPressed: () {
                        // 관리자 페이지를 다이얼로그로 표시
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
          // 메인 컨텐츠 (2단 레이아웃)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 왼쪽: 오늘 할 일 (모든 프로젝트 종합)
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // 헤더
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
                          color: colorScheme.primary.withOpacity(0.2),
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
                  // 오늘 할 일 목록 (프로젝트별로 그룹화)
                  todayTasks.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 48,
                                  color: colorScheme.onSurface.withOpacity(0.5),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '오늘 할 일이 없습니다',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: allProjects.where((project) {
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
                                  colorScheme.surface.withOpacity(0.5),
                                  colorScheme.surface.withOpacity(0.4),
                                ],
                                borderColor: project.color.withOpacity(0.4),
                                borderWidth: 1.0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 프로젝트 헤더
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
                                            color: project.color.withOpacity(0.2),
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
                                    // 프로젝트별 태스크 목록
                                    ...projectTasks.map((task) {
                                      final statusColor = task.status.color;
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => TaskDetailScreen(task: task),
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(12.0),
                                          child: GlassContainer(
                                            padding: const EdgeInsets.all(16),
                                            borderRadius: 12.0,
                                            blur: 15.0,
                                            borderWidth: 1.0,
                                            gradientColors: [
                                              colorScheme.surface.withOpacity(0.6),
                                              colorScheme.surface.withOpacity(0.5),
                                            ],
                                            borderColor: statusColor.withOpacity(0.3),
                                            child: Row(
                                            children: [
                                              // 상태 색상 인디케이터
                                              Container(
                                                width: 4,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: statusColor,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              // 태스크 내용
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
                                                          color: colorScheme.onSurface.withOpacity(0.7),
                                                        ),
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                    // 할당된 팀원 태그
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
                                                                  colorScheme.primary.withOpacity(0.2),
                                                                  colorScheme.primary.withOpacity(0.1),
                                                                ],
                                                                borderColor: colorScheme.primary.withOpacity(0.3),
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
                                              // 상태 배지
                                              GlassContainer(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                borderRadius: 12.0,
                                                blur: 15.0,
                                                gradientColors: [
                                                  statusColor.withOpacity(0.3),
                                                  statusColor.withOpacity(0.2),
                                                ],
                                                borderColor: statusColor.withOpacity(0.5),
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
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                // 세로 구분선
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  color: colorScheme.onSurface.withOpacity(0.2),
                ),
                // 오른쪽: 프로젝트별 진행률
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                  // 헤더
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
                  // 프로젝트별 진행률 카드
                  if (allProjects.isEmpty)
                    GlassContainer(
                      padding: const EdgeInsets.all(40),
                      borderRadius: 20.0,
                      blur: 25.0,
                      gradientColors: [
                        colorScheme.surface.withOpacity(0.4),
                        colorScheme.surface.withOpacity(0.3),
                      ],
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 48,
                              color: colorScheme.onSurface.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '프로젝트가 없습니다',
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface.withOpacity(0.7),
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
                            colorScheme.surface.withOpacity(0.4),
                            colorScheme.surface.withOpacity(0.3),
                          ],
                          borderColor: project.color.withOpacity(0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 프로젝트 헤더
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
                              // 진행률 바
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 12,
                                  backgroundColor: colorScheme.surface.withOpacity(0.3),
                                  valueColor: AlwaysStoppedAnimation<Color>(project.color),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // 태스크 통계
                              Row(
                                children: [
                                  Icon(
                                    Icons.task,
                                    size: 16,
                                    color: colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '전체: $taskCount개',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface.withOpacity(0.7),
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
                                      color: colorScheme.onSurface.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
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

  /// 할당된 팀원 목록 로드
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
