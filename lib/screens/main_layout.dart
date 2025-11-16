import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../widgets/glass_container.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'kanban_screen.dart';
import 'calendar_screen.dart';
import 'gantt_chart_screen.dart';
import 'quick_task_screen.dart';
import 'admin_approval_screen.dart';

/// 메인 레이아웃 - Slack 스타일 (왼쪽 사이드바 + 오른쪽 컨텐츠)
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0; // 선택된 메뉴 인덱스

  // 메뉴 항목 정의 (상태로 관리하여 드래그로 순서 변경 가능)
  late List<MenuItem> _menuItems;

  @override
  void initState() {
    super.initState();
    _loadMenuItems();
  }

  /// 메뉴 아이템 로드 (저장된 순서가 있으면 사용, 없으면 기본 순서)
  Future<void> _loadMenuItems() async {
    final defaultItems = [
      MenuItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: '홈',
        index: 0,
      ),
      MenuItem(
        icon: Icons.view_kanban_outlined,
        selectedIcon: Icons.view_kanban,
        label: '칸반 보드',
        index: 1,
      ),
      MenuItem(
        icon: Icons.calendar_today_outlined,
        selectedIcon: Icons.calendar_today,
        label: '달력',
        index: 2,
      ),
      MenuItem(
        icon: Icons.timeline_outlined,
        selectedIcon: Icons.timeline,
        label: '간트 차트',
        index: 3,
      ),
      MenuItem(
        icon: Icons.add_task_outlined,
        selectedIcon: Icons.add_task,
        label: '빠른 추가',
        index: 4,
      ),
    ];

    // SharedPreferences에서 저장된 순서 로드
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('menu_item_order');
      if (savedOrder != null && savedOrder.length == defaultItems.length) {
        // 저장된 순서대로 재정렬
        final orderedItems = <MenuItem>[];
        for (final label in savedOrder) {
          final item = defaultItems.firstWhere(
            (item) => item.label == label,
            orElse: () => defaultItems[0],
          );
          orderedItems.add(item);
        }
        // index 업데이트
        for (int i = 0; i < orderedItems.length; i++) {
          orderedItems[i] = MenuItem(
            icon: orderedItems[i].icon,
            selectedIcon: orderedItems[i].selectedIcon,
            label: orderedItems[i].label,
            index: i,
          );
        }
        if (mounted) {
          setState(() {
            _menuItems = orderedItems;
          });
        }
        return;
      }
    } catch (e) {
      // 에러 발생 시 기본 순서 사용
    }

    if (mounted) {
      setState(() {
        _menuItems = defaultItems;
      });
    }
  }

  /// 메뉴 아이템 순서 저장
  Future<void> _saveMenuItemsOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = _menuItems.map((item) => item.label).toList();
      await prefs.setStringList('menu_item_order', order);
    } catch (e) {
      // 에러 무시
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context);

    // 관리자 메뉴 추가
    final menuItems = List<MenuItem>.from(_menuItems);
    if (authProvider.isAdmin) {
      menuItems.add(
        MenuItem(
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
          label: '관리자 승인',
          index: 4,
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFF8F9FA),
              colorScheme.primaryContainer.withOpacity(0.3),
            ],
          ),
        ),
        child: Row(
          children: [
            // 왼쪽 사이드바
            _buildSidebar(context, menuItems, colorScheme, authProvider),
            // 오른쪽 컨텐츠 영역
            Expanded(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  /// 사이드바 위젯
  Widget _buildSidebar(
    BuildContext context,
    List<MenuItem> menuItems,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    return Container(
      width: 80,  // 아이콘만 표시하므로 좁게
      child: GlassContainer(
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.all(16),
        borderRadius: 20.0,
        blur: 25.0,
        gradientColors: [
          colorScheme.surface.withOpacity(0.4),
          colorScheme.surface.withOpacity(0.3),
        ],
        child: Column(
          children: [
            // 프로젝트 선택 버튼 (상단)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              child: _buildProjectSelector(context, colorScheme, authProvider),
            ),
            const Divider(height: 1),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                buildDefaultDragHandles: false, // 기본 드래그 핸들 비활성화
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) {
                      newIndex -= 1;
                    }
                    final item = _menuItems.removeAt(oldIndex);
                    _menuItems.insert(newIndex, item);
                    // index 업데이트
                    for (int i = 0; i < _menuItems.length; i++) {
                      _menuItems[i] = MenuItem(
                        icon: _menuItems[i].icon,
                        selectedIcon: _menuItems[i].selectedIcon,
                        label: _menuItems[i].label,
                        index: i,
                      );
                    }
                    // 선택된 인덱스가 변경된 경우 업데이트
                    if (_selectedIndex == oldIndex) {
                      _selectedIndex = newIndex;
                    } else if (_selectedIndex == newIndex && oldIndex < newIndex) {
                      _selectedIndex = newIndex - 1;
                    } else if (_selectedIndex == newIndex && oldIndex > newIndex) {
                      _selectedIndex = newIndex + 1;
                    } else if (_selectedIndex > oldIndex && _selectedIndex <= newIndex) {
                      _selectedIndex -= 1;
                    } else if (_selectedIndex < oldIndex && _selectedIndex >= newIndex) {
                      _selectedIndex += 1;
                    }
                  });
                  _saveMenuItemsOrder();
                },
                children: _menuItems.map((item) {
                  return _buildMenuItem(context, item, colorScheme, key: ValueKey(item.label));
                }).toList(),
              ),
            ),
            const Divider(height: 1),
            // 사용자 정보 및 로그아웃
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // 사용자 정보 (아이콘만)
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: colorScheme.primary.withOpacity(0.2),
                    child: Text(
                      authProvider.currentUser?.username[0].toUpperCase() ?? 'U',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 로그아웃 버튼 (아이콘만)
                  IconButton(
                    icon: Icon(
                      Icons.logout,
                      color: colorScheme.onSurface.withOpacity(0.7),
                      size: 24,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        barrierColor: Colors.black.withOpacity(0.2),
                        builder: (context) {
                          final dialogColorScheme = Theme.of(context).colorScheme;
                          return Dialog(
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            child: GlassContainer(
                              padding: const EdgeInsets.all(0),
                              borderRadius: 24.0,
                              blur: 25.0,
                              gradientColors: [
                                dialogColorScheme.surface.withOpacity(0.6),
                                dialogColorScheme.surface.withOpacity(0.5),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '로그아웃',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: dialogColorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      '로그아웃하시겠습니까?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: dialogColorScheme.onSurface.withOpacity(0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(false),
                                          child: Text(
                                            '취소',
                                            style: TextStyle(
                                              color: dialogColorScheme.onSurface.withOpacity(0.7),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton(
                                          onPressed: () => Navigator.of(context).pop(true),
                                          style: TextButton.styleFrom(
                                            backgroundColor: dialogColorScheme.primary.withOpacity(0.2),
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                          ),
                                          child: Text(
                                            '로그아웃',
                                            style: TextStyle(
                                              color: dialogColorScheme.primary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );

                      if (confirmed == true && context.mounted) {
                        await authProvider.logout();
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        }
                      }
                    },
                    tooltip: '로그아웃',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 프로젝트 선택 버튼
  Widget _buildProjectSelector(
    BuildContext context,
    ColorScheme colorScheme,
    AuthProvider authProvider,
  ) {
    final projectProvider = Provider.of<ProjectProvider>(context);
    final currentProject = projectProvider.currentProject;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showProjectSelectorDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.primary.withOpacity(0.1),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (currentProject != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: currentProject.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentProject.name,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: colorScheme.onSurface.withOpacity(0.7),
                ),
                const SizedBox(height: 4),
                Text(
                  '프로젝트',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 프로젝트 선택 다이얼로그
  void _showProjectSelectorDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 20.0,
            blur: 25.0,
            gradientColors: [
              colorScheme.surface.withOpacity(0.6),
              colorScheme.surface.withOpacity(0.5),
            ],
            child: Consumer<ProjectProvider>(
              builder: (context, provider, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '프로젝트 선택',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.add,
                            color: colorScheme.primary,
                          ),
                          onPressed: () => _showCreateProjectDialog(context),
                          tooltip: '새 프로젝트',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (provider.isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (provider.projects.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          '프로젝트가 없습니다',
                          style: TextStyle(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: provider.projects.length,
                          itemBuilder: (context, index) {
                            final project = provider.projects[index];
                            final isSelected = provider.currentProject?.id == project.id;
                            return ListTile(
                              leading: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: project.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              title: Text(
                                project.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : colorScheme.onSurface,
                                ),
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              onTap: () {
                                provider.setCurrentProject(project.id);
                                Navigator.of(context).pop();
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '닫기',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 프로젝트 생성 다이얼로그
  void _showCreateProjectDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final projectProvider = Provider.of<ProjectProvider>(context, listen: false);
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 20.0,
            blur: 25.0,
            gradientColors: [
              colorScheme.surface.withOpacity(0.6),
              colorScheme.surface.withOpacity(0.5),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '새 프로젝트',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '프로젝트 이름',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        '취소',
                        style: TextStyle(color: colorScheme.onSurface),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (nameController.text.trim().isNotEmpty) {
                          await projectProvider.createProject(
                            name: nameController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        }
                      },
                      child: const Text('생성'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 메뉴 항목 위젯
  Widget _buildMenuItem(
    BuildContext context,
    MenuItem item,
    ColorScheme colorScheme, {
    Key? key,
  }) {
    final isSelected = _selectedIndex == item.index;
    
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedIndex = item.index;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: ReorderableDragStartListener(
            index: item.index,
            child: Container(
              width: double.infinity,
              height: 56, // 고정 높이로 정렬 일관성 확보
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isSelected
                    ? colorScheme.primary.withOpacity(0.15)
                    : Colors.transparent,
              ),
              alignment: Alignment.center, // 아이콘을 정확히 중앙에 배치
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withOpacity(0.7),
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }


  /// 컨텐츠 영역
  Widget _buildContent(BuildContext context) {
    // 현재 선택된 메뉴 아이템의 label을 기반으로 화면 반환
    if (_selectedIndex >= 0 && _selectedIndex < _menuItems.length) {
      final selectedItem = _menuItems[_selectedIndex];
      return _getScreenByLabel(selectedItem.label);
    }
    return const DashboardScreen();
  }

  /// label에 따라 화면 반환
  Widget _getScreenByLabel(String label) {
    switch (label) {
      case '홈':
        return const DashboardScreen();
      case '칸반 보드':
        return const KanbanScreen();
      case '달력':
        return const CalendarScreen();
      case '간트 차트':
        return const GanttChartScreen();
      case '빠른 추가':
        return const QuickTaskScreen();
      case '관리자 승인':
        return const AdminApprovalScreen();
      default:
        return const DashboardScreen();
    }
  }
}

/// 메뉴 항목 모델
class MenuItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;

  MenuItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
  });
}

