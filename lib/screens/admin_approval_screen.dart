import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/glass_container.dart';

/// 관리자 승인 화면 - Liquid Glass 디자인
class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  List<User> _pendingUsers = [];
  List<User> _approvedUsers = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        if (_tabController.index == 0) {
          _loadPendingUsers();
        } else {
          _loadApprovedUsers();
        }
      }
    });
    _loadPendingUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _authService.getPendingUsers();
      setState(() {
        _pendingUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _loadApprovedUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _authService.getApprovedUsers();
      setState(() {
        _approvedUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('오류 발생: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _approveUser(User user) async {
    try {
      await _authService.approveUser(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('사용자가 승인되었습니다.'),
            backgroundColor: Colors.green.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadPendingUsers();
        _loadApprovedUsers(); // 승인된 사용자 목록도 새로고침
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('승인 실패: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _grantPMPermission(User user) async {
    try {
      await _authService.grantPMPermission(user.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${user.username}님에게 PM 권한이 부여되었습니다.'),
            backgroundColor: Colors.green.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadApprovedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PM 권한 부여 실패: $e'),
            backgroundColor: Colors.red.withOpacity(0.8),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _revokePMPermission(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            dialogColorScheme.surface.withOpacity(0.3),
            dialogColorScheme.surface.withOpacity(0.2),
          ],
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            title: Text(
              'PM 권한 제거',
              style: TextStyle(color: dialogColorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '${user.username}님의 PM 권한을 제거하시겠습니까?',
              style: TextStyle(color: dialogColorScheme.onSurface.withOpacity(0.9)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  '취소',
                  style: TextStyle(color: dialogColorScheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  '제거',
                  style: TextStyle(color: dialogColorScheme.error, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        await _authService.revokePMPermission(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.username}님의 PM 권한이 제거되었습니다.'),
              backgroundColor: Colors.orange.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadApprovedUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PM 권한 제거 실패: $e'),
              backgroundColor: Colors.red.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _rejectUser(User user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dialogColorScheme = Theme.of(context).colorScheme;
        return GlassContainer(
          padding: const EdgeInsets.all(24),
          borderRadius: 20.0,
          blur: 25.0,
          gradientColors: [
            dialogColorScheme.surface.withOpacity(0.3),
            dialogColorScheme.surface.withOpacity(0.2),
          ],
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            title: Text(
              '사용자 거부',
              style: TextStyle(color: dialogColorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
            content: Text(
              '${user.username}님의 회원가입을 거부하시겠습니까?',
              style: TextStyle(color: dialogColorScheme.onSurface.withOpacity(0.9)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  '취소',
                  style: TextStyle(color: dialogColorScheme.onSurface),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  '거부',
                  style: TextStyle(color: dialogColorScheme.error, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed == true) {
      try {
        await _authService.rejectUser(user.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('사용자가 거부되었습니다.'),
              backgroundColor: Colors.orange.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _loadPendingUsers();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('거부 실패: $e'),
              backgroundColor: Colors.red.withOpacity(0.8),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 1200,
          maxHeight: 800,
        ),
        child: GlassContainer(
          padding: const EdgeInsets.all(24.0),
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
          // 헤더
          Row(
            children: [
              Text(
                '사용자 관리',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.primary.withOpacity(0.3),
                  colorScheme.primary.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.refresh, color: colorScheme.primary),
                  onPressed: () {
                    if (_tabController.index == 0) {
                      _loadPendingUsers();
                    } else {
                      _loadApprovedUsers();
                    }
                  },
                  tooltip: '새로고침',
                ),
              ),
              const SizedBox(width: 8),
              GlassContainer(
                padding: EdgeInsets.zero,
                borderRadius: 12.0,
                blur: 20.0,
                gradientColors: [
                  colorScheme.surface.withOpacity(0.3),
                  colorScheme.surface.withOpacity(0.2),
                ],
                child: IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: '닫기',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // 탭
          Material(
            color: Colors.transparent,
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 12.0,
              blur: 20.0,
              gradientColors: [
                colorScheme.surface.withOpacity(0.3),
                colorScheme.surface.withOpacity(0.2),
              ],
              child: TabBar(
                controller: _tabController,
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurface.withOpacity(0.6),
                indicatorColor: colorScheme.primary,
                tabs: const [
                  Tab(text: '승인 대기'),
                  Tab(text: '승인된 사용자'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 컨텐츠
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 승인 대기 탭
                _pendingUsers.isEmpty
                        ? Center(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(40),
                              borderRadius: 30.0,
                              blur: 25.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.3),
                                colorScheme.surface.withOpacity(0.2),
                              ],
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    size: 64,
                                    color: colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '승인 대기 중인 사용자가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colorScheme.onSurface.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPendingUsers,
                            color: colorScheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _pendingUsers.length,
                              itemBuilder: (context, index) {
                                final user = _pendingUsers[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(20),
                                    borderRadius: 20.0,
                                    blur: 20.0,
                                    gradientColors: [
                                      colorScheme.surface.withOpacity(0.25),
                                      colorScheme.surface.withOpacity(0.18),
                                    ],
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                user.username,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.check, color: Colors.green),
                                              onPressed: () => _approveUser(user),
                                              tooltip: '승인',
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.green.withOpacity(0.2),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              icon: const Icon(Icons.close, color: Colors.red),
                                              onPressed: () => _rejectUser(user),
                                              tooltip: '거부',
                                              style: IconButton.styleFrom(
                                                backgroundColor: Colors.red.withOpacity(0.2),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '이메일: ${user.email}',
                                          style: TextStyle(
                                            color: colorScheme.onSurface.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '가입일: ${_formatDate(user.createdAt)}',
                                          style: TextStyle(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                // 승인된 사용자 탭
                _approvedUsers.isEmpty
                        ? Center(
                            child: GlassContainer(
                              padding: const EdgeInsets.all(40),
                              borderRadius: 30.0,
                              blur: 25.0,
                              gradientColors: [
                                colorScheme.surface.withOpacity(0.3),
                                colorScheme.surface.withOpacity(0.2),
                              ],
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: colorScheme.onSurface,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    '승인된 사용자가 없습니다',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: colorScheme.onSurface.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadApprovedUsers,
                            color: colorScheme.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _approvedUsers.length,
                              itemBuilder: (context, index) {
                                final user = _approvedUsers[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: GlassContainer(
                                    padding: const EdgeInsets.all(20),
                                    borderRadius: 20.0,
                                    blur: 20.0,
                                    gradientColors: [
                                      colorScheme.surface.withOpacity(0.25),
                                      colorScheme.surface.withOpacity(0.18),
                                    ],
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        user.username,
                                                        style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 20,
                                                          color: colorScheme.onSurface,
                                                        ),
                                                      ),
                                                      if (user.isAdmin) ...[
                                                        const SizedBox(width: 8),
                                                        GlassContainer(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          borderRadius: 8.0,
                                                          blur: 15.0,
                                                          gradientColors: [
                                                            colorScheme.primary.withOpacity(0.3),
                                                            colorScheme.primary.withOpacity(0.2),
                                                          ],
                                                          child: Text(
                                                            '관리자',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: colorScheme.primary,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      if (user.isPM) ...[
                                                        const SizedBox(width: 8),
                                                        GlassContainer(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                          borderRadius: 8.0,
                                                          blur: 15.0,
                                                          gradientColors: [
                                                            Colors.orange.withOpacity(0.3),
                                                            Colors.orange.withOpacity(0.2),
                                                          ],
                                                          child: Text(
                                                            'PM',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.orange,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (!user.isAdmin)
                                              IconButton(
                                                icon: Icon(
                                                  user.isPM ? Icons.star : Icons.star_border,
                                                  color: user.isPM ? Colors.orange : colorScheme.onSurface.withOpacity(0.5),
                                                ),
                                                onPressed: () {
                                                  if (user.isPM) {
                                                    _revokePMPermission(user);
                                                  } else {
                                                    _grantPMPermission(user);
                                                  }
                                                },
                                                tooltip: user.isPM ? 'PM 권한 제거' : 'PM 권한 부여',
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          '이메일: ${user.email}',
                                          style: TextStyle(
                                            color: colorScheme.onSurface.withOpacity(0.9),
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          '가입일: ${_formatDate(user.createdAt)}',
                                          style: TextStyle(
                                            color: colorScheme.onSurface.withOpacity(0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
