import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/project_provider.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/project_info/project_header_widget.dart';
import 'project_info/overview_tab.dart';
import 'project_info/tasks_tab.dart';
import 'project_info/patch_tab.dart';
import 'project_info/members_tab.dart';
import 'project_info/settings_tab.dart';

/// 프로젝트 정보 화면 - 탭 기반 (개요 / 작업 목록 / 패치 내역 / 설정)
class ProjectInfoScreen extends StatefulWidget {
  const ProjectInfoScreen({super.key});

  @override
  State<ProjectInfoScreen> createState() => _ProjectInfoScreenState();
}

class _ProjectInfoScreenState extends State<ProjectInfoScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  List<User> _teamMembers = [];
  List<User> _allUsers = [];
  bool _loadingMembers = false;
  String? _lastProjectId;

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTeamMembers();
      _initSettingsControllers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _initSettingsControllers() {
    final project = context.read<ProjectProvider>().currentProject;
    if (project != null) {
      _nameController.text = project.name;
      _descriptionController.text = project.description ?? '';
    }
  }

  Future<void> _loadTeamMembers() async {
    final project = context.read<ProjectProvider>().currentProject;
    if (project == null) return;

    setState(() => _loadingMembers = true);
    try {
      final allUsers = await _authService.getAllUsers();
      final members =
          allUsers.where((u) => project.teamMemberIds.contains(u.id)).toList();
      if (mounted) setState(() {
        _allUsers = allUsers;
        _teamMembers = members;
      });
    } catch (e) {
      debugPrint('[ProjectInfo] _loadTeamMembers error: $e');
    }
    if (mounted) setState(() => _loadingMembers = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = context.watch<ProjectProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final authProvider = context.watch<AuthProvider>();
    final project = projectProvider.currentProject;

    if (project == null) {
      return const Center(child: Text('프로젝트를 선택해주세요'));
    }

    if (project.id != _lastProjectId) {
      _lastProjectId = project.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadTeamMembers();
        _initSettingsControllers();
      });
    }

    final allTasks = taskProvider.tasks;
    final isPM = authProvider.currentUser?.id == project.creatorId ||
        (authProvider.currentUser?.isAdmin ?? false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // 프로젝트 헤더
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: ProjectHeader(project: project),
          ),
          const SizedBox(height: 16),

          // 탭 바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildTabBar(colorScheme),
          ),

          // 탭 콘텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                OverviewTab(
                  project: project,
                  allTasks: allTasks,
                  teamMembers: _teamMembers,
                  isPM: isPM,
                ),
                TasksTab(
                  allTasks: allTasks,
                  teamMembers: _teamMembers,
                  allUsers: _allUsers,
                ),
                const PatchTab(),
                MembersTab(
                  project: project,
                  allTasks: allTasks,
                  teamMembers: _teamMembers,
                  teamMembersLoading: _loadingMembers,
                  isPM: isPM,
                  onMemberChanged: _loadTeamMembers,
                  authService: _authService,
                ),
                SettingsTab(
                  project: project,
                  isPM: isPM,
                  nameController: _nameController,
                  descriptionController: _descriptionController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.5),
        indicatorColor: colorScheme.primary,
        indicatorWeight: 2.5,
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.dashboard_outlined, size: 18),
              SizedBox(width: 6),
              Text('개요'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.checklist_outlined, size: 18),
              SizedBox(width: 6),
              Text('작업 목록'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.history_outlined, size: 18),
              SizedBox(width: 6),
              Text('패치 내역'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outlined, size: 18),
              SizedBox(width: 6),
              Text('팀원 관리'),
            ]),
          ),
          Tab(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 6),
              Text('설정'),
            ]),
          ),
        ],
      ),
    );
  }
}
