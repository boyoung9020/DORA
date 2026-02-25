import 'package:flutter/foundation.dart';
import '../models/workspace.dart';
import '../services/workspace_service.dart';

/// 워크스페이스 상태 관리 Provider
class WorkspaceProvider extends ChangeNotifier {
  final WorkspaceService _service = WorkspaceService();

  List<Workspace> _workspaces = [];
  Workspace? _currentWorkspace;
  List<WorkspaceMember> _currentMembers = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<Workspace> get workspaces => _workspaces;
  Workspace? get currentWorkspace => _currentWorkspace;
  List<WorkspaceMember> get currentMembers => _currentMembers;
  bool get isLoading => _isLoading;
  bool get hasLoaded => _hasLoaded;
  String? get errorMessage => _errorMessage;

  /// 현재 워크스페이스 ID
  String? get currentWorkspaceId => _currentWorkspace?.id;

  /// 현재 사용자가 현재 워크스페이스의 owner인지
  bool isOwnerOf(String userId) => _currentWorkspace?.ownerId == userId;

  /// 워크스페이스 목록 로드
  Future<void> loadWorkspaces() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _workspaces = await _service.getMyWorkspaces();

      // 현재 워크스페이스가 없거나 목록에 없으면 첫 번째로 설정
      if (_currentWorkspace == null && _workspaces.isNotEmpty) {
        _currentWorkspace = _workspaces.first;
        await _loadCurrentMembers();
      } else if (_currentWorkspace != null) {
        final found = _workspaces.where((w) => w.id == _currentWorkspace!.id);
        if (found.isEmpty && _workspaces.isNotEmpty) {
          _currentWorkspace = _workspaces.first;
          await _loadCurrentMembers();
        } else if (found.isNotEmpty) {
          _currentWorkspace = found.first;
        }
      }
    } catch (e) {
      _errorMessage = '워크스페이스 목록을 불러오는 중 오류: $e';
    } finally {
      _hasLoaded = true;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 워크스페이스 선택
  Future<void> selectWorkspace(Workspace ws) async {
    _currentWorkspace = ws;
    _currentMembers = [];
    notifyListeners();
    await _loadCurrentMembers();
  }

  /// 현재 워크스페이스 멤버 로드
  Future<void> _loadCurrentMembers() async {
    if (_currentWorkspace == null) return;
    try {
      _currentMembers = await _service.getMembers(_currentWorkspace!.id);
      notifyListeners();
    } catch (_) {}
  }

  /// 워크스페이스 생성
  Future<bool> createWorkspace(String name, String? description) async {
    try {
      final ws = await _service.createWorkspace(
        name: name,
        description: description,
      );
      _workspaces.add(ws);
      _currentWorkspace = ws;
      await _loadCurrentMembers();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '워크스페이스 생성 중 오류: $e';
      notifyListeners();
      return false;
    }
  }

  /// 초대 토큰으로 참여
  Future<bool> joinByToken(String token) async {
    try {
      final ws = await _service.joinByToken(token);
      // 이미 참여한 워크스페이스 중복 차단
      final alreadyMember = _workspaces.any((w) => w.id == ws.id);
      if (alreadyMember) {
        _errorMessage = '이미 참여한 워크스페이스입니다';
        notifyListeners();
        return false;
      }
      _workspaces.add(ws);
      _currentWorkspace = ws;
      await _loadCurrentMembers();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().contains('유효하지 않은')
          ? '유효하지 않은 초대 코드입니다'
          : '참여 중 오류: $e';
      notifyListeners();
      return false;
    }
  }

  /// 초대 링크 생성
  String buildInviteLink(String inviteToken) =>
      _service.buildInviteLink(inviteToken);

  /// 초대 토큰 재발급
  Future<bool> regenerateInviteToken() async {
    if (_currentWorkspace == null) return false;
    try {
      final updated = await _service.regenerateInviteToken(
        _currentWorkspace!.id,
      );
      final idx = _workspaces.indexWhere((w) => w.id == updated.id);
      if (idx >= 0) _workspaces[idx] = updated;
      _currentWorkspace = updated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '토큰 재발급 중 오류: $e';
      notifyListeners();
      return false;
    }
  }

  /// 멤버 강퇴
  Future<bool> removeMember(String userId) async {
    if (_currentWorkspace == null) return false;
    try {
      await _service.removeMember(_currentWorkspace!.id, userId);
      _currentMembers.removeWhere((m) => m.userId == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = '강퇴 중 오류: $e';
      notifyListeners();
      return false;
    }
  }

  /// 워크스페이스 탈퇴
  Future<bool> leaveWorkspace() async {
    if (_currentWorkspace == null) return false;
    try {
      await _service.leaveWorkspace(_currentWorkspace!.id);
      _workspaces.removeWhere((w) => w.id == _currentWorkspace!.id);
      _currentWorkspace = _workspaces.isNotEmpty ? _workspaces.first : null;
      _currentMembers = [];
      if (_currentWorkspace != null) await _loadCurrentMembers();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().contains('오너')
          ? '오너는 워크스페이스를 탈퇴할 수 없습니다'
          : '탈퇴 중 오류: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// 로그아웃 시 초기화
  void reset() {
    _workspaces = [];
    _currentWorkspace = null;
    _currentMembers = [];
    _hasLoaded = false;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
}
