import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/task_provider.dart';
import '../../providers/project_provider.dart';
import '../../services/upload_service.dart';
import '../../utils/api_client.dart';
import '../../utils/avatar_color.dart';
import '../../utils/file_download.dart';
import '../../widgets/glass_container.dart';
import '../../models/patch.dart';
import '../../services/patch_service.dart';
import '../../models/project_site.dart';
import '../../services/project_site_service.dart';
import '../../providers/github_provider.dart';

class PatchTab extends StatefulWidget {
  const PatchTab({super.key});

  @override
  State<PatchTab> createState() => _PatchTabState();
}

class _PatchTabState extends State<PatchTab> {
  final PatchService _service = PatchService();
  final ProjectSiteService _siteService = ProjectSiteService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _siteFilters = {};
  bool _sortDescending = true;
  bool _isLoading = false;
  bool _isSavingChecklist = false;
  String? _error;
  String? _currentProjectId;
  List<Patch> _patches = [];

  // ── 사이드 패널 상태
  Patch? _selectedPatch;
  List<CheckItem> _steps = [];
  List<CheckItem> _testItems = [];

  // 체크리스트 추가 입력
  final TextEditingController _stepAddCtrl = TextEditingController();
  final TextEditingController _testAddCtrl = TextEditingController();

  // 특이사항
  final TextEditingController _notesCtrl = TextEditingController();
  final FocusNode _notesFocus = FocusNode();
  bool _isUploadingNoteImage = false;
  final UploadService _uploadService = UploadService();
  final ImagePicker _imagePicker = ImagePicker();

  // 프리셋 (이름 있는 복수 프리셋)
  List<Map<String, dynamic>> _presets = [];

  // 패치 정보 편집 상태
  bool _isEditingPatchInfo = false;
  final TextEditingController _editSiteCtrl = TextEditingController();
  final TextEditingController _editVersionCtrl = TextEditingController();
  final TextEditingController _editContentCtrl = TextEditingController();
  DateTime? _editDate;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(
        () => setState(() => _searchQuery = _searchController.text));
    _notesFocus.addListener(() {
      if (!_notesFocus.hasFocus) _saveNotes();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = context.watch<ProjectProvider>().currentProject?.id;
    if (projectId != _currentProjectId) {
      _currentProjectId = projectId;
      _selectedPatch = null;
      if (projectId != null) {
        _loadPatches(projectId);
        _loadPresets(projectId);
      } else {
        setState(() => _patches = []);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _stepAddCtrl.dispose();
    _testAddCtrl.dispose();
    _notesCtrl.dispose();
    _notesFocus.dispose();
    _editSiteCtrl.dispose();
    _editVersionCtrl.dispose();
    _editContentCtrl.dispose();
    super.dispose();
  }

  Color _tagColor(String tag) => AvatarColor.getColorForUser(tag);

  List<Patch> _getFilteredData() {
    var data = _patches.toList();
    if (_siteFilters.isNotEmpty) {
      data = data.where((p) => _siteFilters.contains(p.site)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      data = data
          .where((p) =>
              p.content.toLowerCase().contains(q) ||
              p.version.toLowerCase().contains(q) ||
              p.site.toLowerCase().contains(q))
          .toList();
    }
    data.sort((a, b) => _sortDescending
        ? b.patchDate.compareTo(a.patchDate)
        : a.patchDate.compareTo(b.patchDate));
    return data;
  }

  List<String> _getAllSiteTags(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final projectId = context.read<ProjectProvider>().currentProject?.id;
    final fromTasks = taskProvider.allTasks
        .where((t) => projectId == null || t.projectId == projectId)
        .expand((t) => t.siteTags)
        .toSet();
    final fromPatches = _patches.map((p) => p.site).where((s) => s.isNotEmpty);
    return {...fromTasks, ...fromPatches}.toList()..sort();
  }

  Future<void> _loadPatches(String projectId) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.getPatches(projectId: projectId);
      if (!mounted) return;
      setState(() => _patches = data);
      // 선택된 패치가 있으면 최신 데이터로 갱신
      if (_selectedPatch != null) {
        final updated =
            data.where((p) => p.id == _selectedPatch!.id).firstOrNull;
        if (updated != null) _applySelectedPatch(updated);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applySelectedPatch(Patch patch) {
    _selectedPatch = patch;
    _steps = List.from(patch.steps);
    _testItems = List.from(patch.testItems);
    _notesCtrl.text = patch.notes;
    _isEditingPatchInfo = false;
  }

  void _selectPatch(Patch patch) {
    setState(() {
      if (_selectedPatch?.id == patch.id) {
        _selectedPatch = null;
        _steps = [];
        _testItems = [];
        _isEditingPatchInfo = false;
      } else {
        _applySelectedPatch(patch);
      }
    });
  }

  // ── 체크리스트 저장 (체크 토글 / 항목 추가·삭제 시)
  Future<void> _saveChecklist() async {
    final patch = _selectedPatch;
    if (patch == null) return;
    setState(() => _isSavingChecklist = true);
    try {
      final newStatus = Patch.computeStatus(_steps, _testItems);
      final updated = await _service.updatePatch(
        patchId: patch.id,
        steps: _steps,
        testItems: _testItems,
        status: newStatus,
      );
      if (!mounted) return;
      setState(() {
        final idx = _patches.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _patches[idx] = updated;
        _selectedPatch = updated;
        _steps = List.from(updated.steps);
        _testItems = List.from(updated.testItems);
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSavingChecklist = false);
    }
  }

  // ── 특이사항 저장 (포커스 해제 시)
  Future<void> _saveNotes() async {
    final patch = _selectedPatch;
    if (patch == null) return;
    final text = _notesCtrl.text;
    if (text == patch.notes) return;
    try {
      final updated = await _service.updatePatch(
        patchId: patch.id,
        notes: text,
      );
      if (!mounted) return;
      setState(() {
        final idx = _patches.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _patches[idx] = updated;
        _selectedPatch = updated;
      });
    } catch (_) {}
  }

  // ── 특이사항 이미지 업로드
  Future<void> _pickAndUploadNoteImage() async {
    final patch = _selectedPatch;
    if (patch == null) return;
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _isUploadingNoteImage = true);
    try {
      final url = await _uploadService.uploadImageFromXFile(picked);
      final newUrls = [...patch.noteImageUrls, url];
      final updated = await _service.updatePatch(
        patchId: patch.id,
        noteImageUrls: newUrls,
      );
      if (!mounted) return;
      setState(() {
        final idx = _patches.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _patches[idx] = updated;
        _selectedPatch = updated;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isUploadingNoteImage = false);
    }
  }

  // ── 특이사항 이미지 삭제
  Future<void> _deleteNoteImage(int index) async {
    final patch = _selectedPatch;
    if (patch == null) return;
    final newUrls = List<String>.from(patch.noteImageUrls)..removeAt(index);
    try {
      final updated = await _service.updatePatch(
        patchId: patch.id,
        noteImageUrls: newUrls,
      );
      if (!mounted) return;
      setState(() {
        final idx = _patches.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _patches[idx] = updated;
        _selectedPatch = updated;
      });
    } catch (_) {}
  }

  // ── 특이사항 이미지 다운로드
  Future<void> _downloadNoteImage(String url) async {
    final resolved = url.startsWith('http') ? url : '${ApiClient.baseUrl}$url';
    try {
      final resp = await http.get(Uri.parse(resolved));
      if (resp.statusCode != 200) return;
      final fileName = resolved.split('/').last.split('?').first;
      await saveFileFromBytes(resp.bodyBytes, fileName.isNotEmpty ? fileName : 'image.jpg');
    } catch (_) {}
  }

  // ── 프리셋 로드/저장 (이름 있는 복수 프리셋)
  static const String _presetKeyPrefix = 'patch_presets_v2_';

  Future<void> _loadPresets(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_presetKeyPrefix$projectId');
    if (!mounted) return;
    if (raw == null || raw.isEmpty) { setState(() => _presets = []); return; }
    try {
      final list = jsonDecode(raw) as List;
      setState(() => _presets = list.cast<Map<String, dynamic>>());
    } catch (_) { setState(() => _presets = []); }
  }

  Future<void> _persistPresets() async {
    final projectId = _currentProjectId;
    if (projectId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_presetKeyPrefix$projectId', jsonEncode(_presets));
  }

  // 현재 steps/testItems를 이름 붙여 프리셋으로 저장
  void _showSavePresetDialog(BuildContext ctx, ColorScheme colorScheme) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('프리셋 저장', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '프리셋 이름 (예: 표준 배포)', border: OutlineInputBorder(), isDense: true),
          onSubmitted: (_) => Navigator.pop(dCtx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('저장'),
          ),
        ],
      ),
    ).then((ok) async {
      if (ok != true) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final entry = {
        'name': name,
        'steps': _steps.map((e) => {'text': e.text, 'checked': false}).toList(),
        'test_items': _testItems.map((e) => {'text': e.text, 'checked': false}).toList(),
      };
      setState(() => _presets = [..._presets, entry]);
      await _persistPresets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$name" 프리셋이 저장되었습니다'), duration: const Duration(seconds: 2)),
        );
      }
    });
  }

  // 프리셋 선택 메뉴 (detail panel용)
  void _showLoadPresetMenu(BuildContext ctx, ColorScheme colorScheme) {
    if (_presets.isEmpty) return;
    final box = ctx.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(ctx).context.findRenderObject() as RenderBox?;
    final offset = box != null && overlay != null
        ? box.localToGlobal(Offset(0, box.size.height + 4), ancestor: overlay)
        : Offset.zero;
    showMenu<int>(
      context: ctx,
      position: RelativeRect.fromLTRB(offset.dx, offset.dy, offset.dx + 200, offset.dy + 400),
      items: [
        ..._presets.asMap().entries.map((e) => PopupMenuItem<int>(
          value: e.key,
          height: 40,
          child: Row(children: [
            Icon(Icons.bookmark_outline, size: 14, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(e.value['name'] as String, style: const TextStyle(fontSize: 13))),
            Text('${(e.value['steps'] as List).length}+${(e.value['test_items'] as List).length}',
                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4))),
          ]),
        )),
        if (_presets.isNotEmpty) ...[
          const PopupMenuDivider(),
          PopupMenuItem<int>(
            value: -1,
            height: 36,
            child: Row(children: [
              Icon(Icons.edit_outlined, size: 14, color: colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(width: 8),
              Text('프리셋 관리', style: TextStyle(fontSize: 13, color: colorScheme.onSurface.withValues(alpha: 0.6))),
            ]),
          ),
        ],
      ],
    ).then((idx) {
      if (idx == null) return;
      if (idx == -1) { _showManagePresetsDialog(context, colorScheme); return; }
      _applyPreset(_presets[idx]);
    });
  }

  void _applyPreset(Map<String, dynamic> preset) {
    List<CheckItem> parse(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => CheckItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    setState(() {
      _steps = parse(preset['steps']);
      _testItems = parse(preset['test_items']);
    });
    _saveChecklist();
  }

  Future<void> _applyPresetToNewPatch(String patchId, Map<String, dynamic> preset) async {
    List<CheckItem> parse(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((e) => CheckItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    final updated = await _service.updatePatch(
      patchId: patchId,
      steps: parse(preset['steps']),
      testItems: parse(preset['test_items']),
    );
    if (!mounted) return;
    setState(() {
      final idx = _patches.indexWhere((p) => p.id == updated.id);
      if (idx >= 0) _patches[idx] = updated;
    });
  }

  void _showManagePresetsDialog(BuildContext ctx, ColorScheme colorScheme) {
    showDialog(
      context: ctx,
      builder: (dCtx) => StatefulBuilder(builder: (_, setS) => AlertDialog(
        title: const Text('프리셋 관리', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 320,
          child: _presets.isEmpty
              ? const Text('저장된 프리셋이 없습니다.', style: TextStyle(fontSize: 13))
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: _presets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _presets[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.bookmark_outline, size: 16, color: colorScheme.primary),
                      title: Text(p['name'] as String, style: const TextStyle(fontSize: 13)),
                      subtitle: Text(
                        '패치순서 ${(p['steps'] as List).length}개 · 테스트 ${(p['test_items'] as List).length}개',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error.withValues(alpha: 0.7)),
                        onPressed: () {
                          setS(() => _presets.removeAt(i));
                          setState(() {});
                          _persistPresets();
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('닫기'))],
      )),
    );
  }

  // ── 패치 기본 정보 저장
  Future<void> _savePatchInfo() async {
    final patch = _selectedPatch;
    if (patch == null) return;
    setState(() => _isLoading = true);
    try {
      final updated = await _service.updatePatch(
        patchId: patch.id,
        site: _editSiteCtrl.text.trim(),
        patchDate: _editDate ?? patch.patchDate,
        version: _editVersionCtrl.text.trim(),
        content: _editContentCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        final idx = _patches.indexWhere((p) => p.id == updated.id);
        if (idx >= 0) _patches[idx] = updated;
        _applySelectedPatch(updated);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── 패치 삭제
  Future<void> _deletePatch(Patch patch) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('패치 삭제'),
        content: Text('${patch.dateDisplay} ${patch.site} 패치를 삭제하시겠습니까?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.deletePatch(patchId: patch.id);
      if (!mounted) return;
      setState(() {
        _patches.removeWhere((p) => p.id == patch.id);
        if (_selectedPatch?.id == patch.id) {
          _selectedPatch = null;
          _steps = [];
          _testItems = [];
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEditPatchInfo() {
    final patch = _selectedPatch!;
    _editSiteCtrl.text = patch.site;
    _editVersionCtrl.text = patch.version;
    _editContentCtrl.text = patch.content;
    _editDate = patch.patchDate;
    setState(() => _isEditingPatchInfo = true);
  }

  // ── 사이트 필터 드롭다운
  void _showSiteFilterDropdown(
      BuildContext context, Rect buttonRect, List<String> allSites) {
    final colorScheme = Theme.of(context).colorScheme;
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
          buttonRect.left, buttonRect.bottom + 4, buttonRect.right, 0),
      items: [
        ...allSites.map((site) {
          final isSelected = _siteFilters.contains(site);
          final color = _tagColor(site);
          return PopupMenuItem<void>(
            height: 36,
            onTap: () => setState(() {
              isSelected ? _siteFilters.remove(site) : _siteFilters.add(site);
            }),
            child: Row(children: [
              Icon(
                  isSelected
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 18,
                  color: isSelected
                      ? color
                      : colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 8),
              Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(site,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? color : colorScheme.onSurface)),
            ]),
          );
        }),
        PopupMenuItem<void>(
          height: 36,
          onTap: () => setState(() => _siteFilters.clear()),
          child: Row(children: [
            Icon(Icons.clear_all,
                size: 18,
                color: colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 8),
            Text('초기화',
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.6))),
          ]),
        ),
      ],
    );
  }

  // ── 새 패치 등록 다이얼로그
  void _showAddPatchDialog(
      BuildContext context, List<String> allSites, ColorScheme colorScheme) {
    final projectId = _currentProjectId;
    if (projectId == null) return;

    final siteCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final versionCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    DateTime? selectedDate;
    Map<String, dynamic>? selectedPreset;
    String? selectedGitTag;

    // 태그 로드 트리거
    final ghProvider = context.read<GitHubProvider>();
    if (ghProvider.connectedRepo != null && ghProvider.tags.isEmpty) {
      ghProvider.loadTags(projectId);
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (ctx, setDialogState) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassContainer(
            padding: const EdgeInsets.all(24),
            borderRadius: 16,
            blur: 25,
            gradientColors: [
              colorScheme.surface.withValues(alpha: 0.95),
              colorScheme.surface.withValues(alpha: 0.9),
            ],
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('새 패치 등록',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  Text('사이트',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await _showProjectSiteDropdown(
                          context: dialogContext,
                          projectId: projectId,
                          colorScheme: colorScheme);
                      if (picked != null) {
                        setDialogState(() => siteCtrl.text = picked);
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10)),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            siteCtrl.text.trim().isEmpty
                                ? '사이트 선택'
                                : siteCtrl.text.trim(),
                            style: TextStyle(
                                fontSize: 13,
                                color: siteCtrl.text.trim().isEmpty
                                    ? colorScheme.onSurface
                                        .withValues(alpha: 0.45)
                                    : colorScheme.onSurface),
                          ),
                        ),
                        Icon(Icons.arrow_drop_down,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.6)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text('날짜',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(
                        hintText: '날짜 선택',
                        border: OutlineInputBorder(),
                        isDense: true),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: dialogContext,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedDate = picked;
                          dateCtrl.text =
                              '${picked.year}.${picked.month}.${picked.day}';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _dialogField('버전', versionCtrl, '예) 1.0.0'),
                  if (ghProvider.connectedRepo != null) ...[
                    const SizedBox(height: 10),
                    Text('Git 태그',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 6),
                    ListenableBuilder(
                      listenable: ghProvider,
                      builder: (_, __) {
                        final tags = ghProvider.tags;
                        return InputDecorator(
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.zero),
                          child: DropdownButton<String>(
                            value: selectedGitTag,
                            isExpanded: true,
                            underline: const SizedBox.shrink(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            hint: Text(
                              tags.isEmpty ? '태그 없음' : '태그 선택 (선택사항)',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.45)),
                            ),
                            items: tags
                                .map((t) => DropdownMenuItem(
                                      value: t.name,
                                      child: Row(children: [
                                        Icon(Icons.sell_outlined,
                                            size: 13,
                                            color: colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(t.name,
                                            style:
                                                const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 6),
                                        Text(t.shortSha,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: colorScheme.onSurface
                                                    .withValues(alpha: 0.4),
                                                fontFamily: 'monospace')),
                                      ]),
                                    ))
                                .toList(),
                            onChanged: (val) => setDialogState(() {
                              selectedGitTag = val;
                              if (val != null &&
                                  versionCtrl.text.trim().isEmpty) {
                                versionCtrl.text = val;
                              }
                            }),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  _dialogField('패치 내용', contentCtrl, '패치 내용을 입력하세요'),
                  if (_presets.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('프리셋 적용',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface.withValues(alpha: 0.6))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<int>(
                      value: selectedPreset == null ? -1 : _presets.indexOf(selectedPreset!),
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                      items: [
                        DropdownMenuItem<int>(value: -1,
                          child: Text('적용 안함', style: TextStyle(fontSize: 13,
                              color: colorScheme.onSurface.withValues(alpha: 0.45)))),
                        ..._presets.asMap().entries.map((e) => DropdownMenuItem<int>(
                          value: e.key,
                          child: Row(children: [
                            Icon(Icons.bookmark_outline, size: 13, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Expanded(child: Text(e.value['name'] as String, style: const TextStyle(fontSize: 13))),
                            Text('${(e.value['steps'] as List).length}+${(e.value['test_items'] as List).length}',
                                style: TextStyle(fontSize: 11, color: colorScheme.onSurface.withValues(alpha: 0.4))),
                          ]),
                        )),
                      ],
                      onChanged: (idx) => setDialogState(() =>
                          selectedPreset = (idx == null || idx < 0) ? null : _presets[idx]),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('취소')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _isLoading
                            ? null
                            : () async {
                                final site = siteCtrl.text.trim();
                                final content = contentCtrl.text.trim();
                                if (site.isEmpty ||
                                    selectedDate == null ||
                                    content.isEmpty) return;
                                try {
                                  setState(() => _isLoading = true);
                                  final patch = await _service.createPatch(
                                    projectId: projectId,
                                    site: site,
                                    patchDate: selectedDate!,
                                    version: versionCtrl.text.trim(),
                                    content: content,
                                    gitTag: selectedGitTag,
                                  );
                                  if (selectedPreset != null) {
                                    await _applyPresetToNewPatch(patch.id, selectedPreset!);
                                  }
                                  if (!mounted) return;
                                  await _loadPatches(projectId);
                                  if (!mounted) return;
                                  Navigator.pop(dialogContext);
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false);
                                  }
                                }
                              },
                        child: const Text('등록'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _dialogField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // 사이드 패널
  // ─────────────────────────────────────────

  Widget _buildDetailPanel(Patch patch, ColorScheme colorScheme) {
    final siteColor =
        patch.site.isNotEmpty ? _tagColor(patch.site) : Colors.grey;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: GlassContainer(
        padding: EdgeInsets.zero,
        borderRadius: 0,
        blur: 20,
        gradientColors: [
          Colors.white.withValues(alpha: 0.92),
          Colors.white.withValues(alpha: 0.85),
        ],
        shadowBlurRadius: 0,
        child: Column(
          children: [
            // ── 헤더: 패치 기본 정보 + 편집
            _isEditingPatchInfo
                ? _buildEditPatchInfoHeader(patch, colorScheme)
                : _buildViewPatchInfoHeader(patch, siteColor, colorScheme),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // ── 본문: 체크리스트
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 프리셋 툴바
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_presets.isNotEmpty)
                          Builder(builder: (btnCtx) => TextButton.icon(
                            onPressed: () => _showLoadPresetMenu(btnCtx, colorScheme),
                            icon: const Icon(Icons.bookmark_outline, size: 14),
                            label: const Text('프리셋 불러오기', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              foregroundColor: colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          )),
                        TextButton.icon(
                          onPressed: (_steps.isEmpty && _testItems.isEmpty)
                              ? null
                              : () => _showSavePresetDialog(context, colorScheme),
                          icon: const Icon(Icons.bookmark_add_outlined, size: 14),
                          label: const Text('현재 항목 저장', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurface.withValues(alpha: 0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 패치 순서
                    _buildChecklistSection(
                      icon: Icons.format_list_numbered,
                      title: '패치 순서',
                      items: _steps,
                      addCtrl: _stepAddCtrl,
                      colorScheme: colorScheme,
                      onToggle: (i, val) {
                        setState(() {
                          _steps[i] = _steps[i].copyWith(checked: val);
                        });
                        _saveChecklist();
                      },
                      onAdd: (text) {
                        setState(() =>
                            _steps.add(CheckItem(text: text, checked: false)));
                        _saveChecklist();
                      },
                      onDelete: (i) {
                        setState(() => _steps.removeAt(i));
                        _saveChecklist();
                      },
                    ),
                    const SizedBox(height: 20),
                    Divider(
                        height: 1,
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 20),
                    // 테스트 리스트
                    _buildChecklistSection(
                      icon: Icons.checklist_rounded,
                      title: '테스트 리스트',
                      items: _testItems,
                      addCtrl: _testAddCtrl,
                      colorScheme: colorScheme,
                      onToggle: (i, val) {
                        setState(() {
                          _testItems[i] = _testItems[i].copyWith(checked: val);
                        });
                        _saveChecklist();
                      },
                      onAdd: (text) {
                        setState(() => _testItems
                            .add(CheckItem(text: text, checked: false)));
                        _saveChecklist();
                      },
                      onDelete: (i) {
                        setState(() => _testItems.removeAt(i));
                        _saveChecklist();
                      },
                    ),
                    const SizedBox(height: 20),
                    Divider(
                        height: 1,
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.3)),
                    const SizedBox(height: 20),
                    // ── 특이사항
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note_outlined,
                                size: 14, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text('특이사항',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.8))),
                            const Spacer(),
                            // 이미지 추가 버튼
                            _isUploadingNoteImage
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.primary))
                                : GestureDetector(
                                    onTap: _pickAndUploadNoteImage,
                                    child: Icon(Icons.add_photo_alternate_outlined,
                                        size: 18,
                                        color: colorScheme.primary
                                            .withValues(alpha: 0.7)),
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _notesCtrl,
                          focusNode: _notesFocus,
                          maxLines: 4,
                          minLines: 2,
                          decoration: InputDecoration(
                            hintText: '특이사항을 입력하세요...',
                            hintStyle: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.35)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.4)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            isDense: true,
                          ),
                          style: TextStyle(
                              fontSize: 13, color: colorScheme.onSurface),
                        ),
                        // 이미지 썸네일
                        if (_selectedPatch!.noteImageUrls.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _selectedPatch!.noteImageUrls
                                .asMap()
                                .entries
                                .map((e) => _buildNoteImageThumb(
                                    e.key, e.value, colorScheme))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // ── 하단: 저장 중 인디케이터
            if (_isSavingChecklist)
              LinearProgressIndicator(
                minHeight: 2,
                color: colorScheme.primary,
                backgroundColor: Colors.transparent,
              ),
          ],
        ),
      ),
    );
  }

  // 패치 정보 보기 헤더
  Widget _buildViewPatchInfoHeader(
      Patch patch, Color siteColor, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (patch.site.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: siteColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(patch.site,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: siteColor)),
                ),
              if (patch.site.isNotEmpty) const SizedBox(width: 8),
              Text(patch.dateDisplay,
                  style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.6))),
              if (patch.version.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.5)),
                  ),
                  child: Text(patch.version,
                      style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.65))),
                ),
              ],
              if (patch.gitTag != null && patch.gitTag!.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.sell_outlined,
                        size: 10,
                        color: colorScheme.primary.withValues(alpha: 0.8)),
                    const SizedBox(width: 3),
                    Text(patch.gitTag!,
                        style: TextStyle(
                            fontSize: 11,
                            color:
                                colorScheme.primary.withValues(alpha: 0.9))),
                  ]),
                ),
              ],
              const Spacer(),
              IconButton(
                onPressed: _startEditPatchInfo,
                icon: Icon(Icons.edit_outlined,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.45)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 13,
                tooltip: '정보 편집',
              ),
              IconButton(
                onPressed: () => _deletePatch(patch),
                icon: Icon(Icons.delete_outline,
                    size: 16,
                    color: colorScheme.error.withValues(alpha: 0.6)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 13,
                tooltip: '패치 삭제',
              ),
              IconButton(
                onPressed: () => setState(() {
                  _selectedPatch = null;
                  _steps = [];
                  _testItems = [];
                  _isEditingPatchInfo = false;
                }),
                icon: Icon(Icons.close,
                    size: 16,
                    color: colorScheme.onSurface.withValues(alpha: 0.45)),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 13,
                tooltip: '닫기',
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(patch.content,
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.85)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          // 진행률
          if (patch.totalItems > 0) ...[
            const SizedBox(height: 8),
            _buildProgressBar(patch, colorScheme),
          ],
        ],
      ),
    );
  }

  // 패치 정보 편집 헤더
  Widget _buildEditPatchInfoHeader(Patch patch, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('패치 정보 편집',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface)),
              const Spacer(),
              TextButton(
                  onPressed: () =>
                      setState(() => _isEditingPatchInfo = false),
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 12)),
                  child: const Text('취소')),
              const SizedBox(width: 4),
              FilledButton(
                onPressed: _isLoading ? null : _savePatchInfo,
                style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    textStyle: const TextStyle(fontSize: 12)),
                child: const Text('저장'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 사이트 (드롭다운)
          _buildEditSiteField(patch, colorScheme),
          const SizedBox(height: 8),
          // 날짜
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _editDate ?? patch.patchDate,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => _editDate = picked);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: '날짜',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              child: Row(children: [
                Expanded(
                  child: Text(
                    _editDate != null
                        ? '${_editDate!.year}.${_editDate!.month.toString().padLeft(2, '0')}.${_editDate!.day.toString().padLeft(2, '0')}'
                        : patch.dateDisplay,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Icon(Icons.calendar_today,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editVersionCtrl,
            decoration: const InputDecoration(
                labelText: '버전',
                hintText: '예) 1.0.0',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _editContentCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: '패치 내용',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildEditSiteField(Patch patch, ColorScheme colorScheme) {
    final projectId = _currentProjectId;
    if (projectId == null) return const SizedBox.shrink();
    return InkWell(
      onTap: () async {
        final picked = await _showProjectSiteDropdown(
            context: context,
            projectId: projectId,
            colorScheme: colorScheme);
        if (picked != null) setState(() => _editSiteCtrl.text = picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: '사이트',
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding:
                EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
        child: Row(children: [
          Expanded(
            child: Text(
              _editSiteCtrl.text.trim().isEmpty
                  ? patch.site
                  : _editSiteCtrl.text.trim(),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Icon(Icons.arrow_drop_down,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.5)),
        ]),
      ),
    );
  }

  Widget _buildProgressBar(Patch patch, ColorScheme colorScheme) {
    final total = patch.totalItems;
    final checked = patch.checkedItems;
    final ratio = total > 0 ? checked / total : 0.0;
    final color = patch.status == 'done'
        ? const Color(0xFF4CAF50)
        : patch.status == 'in_progress'
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.2);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 4,
              backgroundColor:
                  colorScheme.onSurface.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$checked/$total',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.5))),
      ],
    );
  }

  Widget _buildNoteImageThumb(
      int index, String url, ColorScheme colorScheme) {
    final resolved = url.startsWith('http')
        ? url
        : '${ApiClient.baseUrl}$url';
    return Stack(
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: Image.network(resolved, fit: BoxFit.contain),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Tooltip(
                      message: '다운로드',
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.download_outlined,
                              color: Colors.white, size: 20),
                          onPressed: () => _downloadNoteImage(url),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              resolved,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                color: colorScheme.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined,
                    size: 24,
                    color: colorScheme.onSurface.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: () => _deleteNoteImage(index),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  size: 11, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  // 체크리스트 섹션 (패치 순서 / 테스트 리스트 공용)
  Widget _buildChecklistSection({
    required IconData icon,
    required String title,
    required List<CheckItem> items,
    required TextEditingController addCtrl,
    required ColorScheme colorScheme,
    required void Function(int, bool) onToggle,
    required void Function(String) onAdd,
    required void Function(int) onDelete,
  }) {
    final checkedCount = items.where((e) => e.checked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.8))),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text('$checkedCount/${items.length}',
                  style: TextStyle(
                      fontSize: 11,
                      color: colorScheme.onSurface.withValues(alpha: 0.45))),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('항목이 없습니다.',
                style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.35))),
          )
        else
          ...items.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 인덱스 번호
                  SizedBox(
                    width: 20,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('${i + 1}.',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.35))),
                    ),
                  ),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: item.checked,
                      onChanged: (v) => onToggle(i, v ?? false),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.text,
                          style: TextStyle(
                              fontSize: 13,
                              decoration: item.checked
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item.checked
                                  ? colorScheme.onSurface
                                      .withValues(alpha: 0.4)
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.85))),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onDelete(i),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(Icons.close,
                          size: 13,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.3)),
                    ),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 4),
        // 추가 입력
        Row(
          children: [
            Icon(Icons.add,
                size: 14,
                color: colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Expanded(
              child: TextField(
                controller: addCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '항목 추가 (Enter)',
                  hintStyle: TextStyle(
                      fontSize: 12,
                      color:
                          colorScheme.onSurface.withValues(alpha: 0.3)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    onAdd(val.trim());
                    addCtrl.clear();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // 테이블 빌드
  // ─────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSites = _getAllSiteTags(context);
    final filteredData = _getFilteredData();
    final hasFilters = _siteFilters.isNotEmpty || _searchQuery.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 왼쪽: 패치 테이블
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassContainer(
              padding: EdgeInsets.zero,
              borderRadius: 16,
              blur: 20,
              gradientColors: [
                Colors.white.withValues(alpha: 0.9),
                Colors.white.withValues(alpha: 0.8),
              ],
              shadowBlurRadius: 8,
              shadowOffset: const Offset(0, 2),
              child: Column(
                children: [
                  // 헤더 툴바
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 220,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              prefixIcon: Icon(Icons.search,
                                  size: 18,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              hintText: '내용, 버전, 사이트 검색...',
                              hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: colorScheme.outlineVariant),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('${filteredData.length}건',
                            style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                        const Spacer(),
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary),
                            ),
                          ),
                        if (hasFilters)
                          TextButton.icon(
                            onPressed: () => setState(() {
                              _siteFilters.clear();
                              _searchController.clear();
                            }),
                            icon: const Icon(Icons.filter_alt_off, size: 16),
                            label: const Text('필터 초기화'),
                            style: TextButton.styleFrom(
                                foregroundColor: colorScheme.primary,
                                textStyle:
                                    const TextStyle(fontSize: 13)),
                          ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () => _showAddPatchDialog(
                              context, allSites, colorScheme),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('새 패치 등록'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            textStyle: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: colorScheme.error, fontSize: 12)),
                    ),
                  // 테이블 헤더
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    color: colorScheme.onSurface.withValues(alpha: 0.03),
                    child: Row(
                      children: [
                        SizedBox(
                            width: 110,
                            child: _buildSiteHeader(
                                context, colorScheme, allSites)),
                        SizedBox(
                            width: 120,
                            child: _buildDateHeader(context, colorScheme)),
                        const SizedBox(
                          width: 110,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text('버전',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        // 상태 컬럼 (신규)
                        const SizedBox(
                          width: 110,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text('상태',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            child: Text('내용',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                      height: 1,
                      color:
                          colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  // 테이블 본문
                  if (filteredData.isEmpty && !_isLoading)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('패치 내역이 없습니다.',
                          style: TextStyle(
                              color: colorScheme.onSurface
                                  .withValues(alpha: 0.5))),
                    )
                  else
                    ...filteredData.map((row) {
                      final isSelected = _selectedPatch?.id == row.id;
                      final site = row.site;
                      final siteColor =
                          site.isNotEmpty ? _tagColor(site) : Colors.grey;
                      return InkWell(
                        onTap: () => _selectPatch(row),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary.withValues(alpha: 0.07)
                                : null,
                            border: Border(
                              bottom: BorderSide(
                                  color: colorScheme.outlineVariant
                                      .withValues(alpha: 0.15)),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 사이트
                              SizedBox(
                                width: 110,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: site.isNotEmpty
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: siteColor
                                                .withValues(alpha: 0.12),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(site,
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: siteColor)),
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              // 날짜
                              SizedBox(
                                width: 120,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 10),
                                  child: Text(row.dateDisplay,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.8))),
                                ),
                              ),
                              // 버전
                              SizedBox(
                                width: 110,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: row.version.isNotEmpty
                                      ? _buildVersionChip(row.version)
                                      : const SizedBox.shrink(),
                                ),
                              ),
                              // 상태 칩
                              SizedBox(
                                width: 110,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8),
                                  child: _buildStatusChip(row, colorScheme),
                                ),
                              ),
                              // 내용
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  child: Text(row.content,
                                      style: TextStyle(
                                          fontSize: 13,
                                          color: colorScheme.onSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
        // ── 오른쪽: 슬라이드 패널
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: _selectedPatch != null ? 480.0 : 0.0,
          child: _selectedPatch != null
              ? ClipRect(
                  child:
                      _buildDetailPanel(_selectedPatch!, colorScheme))
              : null,
        ),
      ],
    );
  }

  Widget _buildVersionChip(String version) {
    const color = Color(0xFF5C7CFA); // 인디고 계열 고정 태그 색
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(version,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }

  Widget _buildStatusChip(Patch patch, ColorScheme colorScheme) {
    late Color chipColor;
    late String label;
    switch (patch.status) {
      case 'done':
        chipColor = const Color(0xFF4CAF50);
        label = '완료';
      case 'in_progress':
        chipColor = colorScheme.primary;
        label = '진행중';
      default:
        chipColor = colorScheme.onSurface.withValues(alpha: 0.35);
        label = '대기중';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: chipColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: chipColor)),
        ),
        if (patch.totalItems > 0) ...[
          const SizedBox(width: 4),
          Text('${patch.checkedItems}/${patch.totalItems}',
              style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurface.withValues(alpha: 0.4))),
        ],
      ],
    );
  }

  Widget _buildDateHeader(BuildContext context, ColorScheme colorScheme) {
    final color = colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('날짜',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 2),
          SizedBox(
            width: 22,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 15,
              splashRadius: 14,
              icon: Icon(
                _sortDescending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: color,
                size: 15,
              ),
              onPressed: () =>
                  setState(() => _sortDescending = !_sortDescending),
              tooltip: _sortDescending ? '오름차순 정렬' : '내림차순 정렬',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteHeader(
      BuildContext context, ColorScheme colorScheme, List<String> allSites) {
    final isActive = _siteFilters.isNotEmpty;
    final color = isActive
        ? colorScheme.primary
        : colorScheme.onSurface.withValues(alpha: 0.7);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('사이트',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(width: 2),
          _FilterIconButton(
            isActive: isActive,
            color: color,
            onTap: (rect) =>
                _showSiteFilterDropdown(context, rect, allSites),
          ),
        ],
      ),
    );
  }

  Future<String?> _showProjectSiteDropdown({
    required BuildContext context,
    required String projectId,
    required ColorScheme colorScheme,
  }) async {
    return showDialog<String?>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassContainer(
          padding: const EdgeInsets.all(18),
          borderRadius: 16,
          blur: 25,
          gradientColors: [
            colorScheme.surface.withValues(alpha: 0.95),
            colorScheme.surface.withValues(alpha: 0.9),
          ],
          child: SizedBox(
            width: 360,
            child: _ProjectSiteDropdown(
              projectId: projectId,
              colorScheme: colorScheme,
              service: _siteService,
              onPicked: (name) => Navigator.pop(dialogContext, name),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
// 사이트 선택 드롭다운
// ────────────────────────────────────────────

class _ProjectSiteDropdown extends StatefulWidget {
  final String projectId;
  final ColorScheme colorScheme;
  final ProjectSiteService service;
  final void Function(String name) onPicked;

  const _ProjectSiteDropdown({
    required this.projectId,
    required this.colorScheme,
    required this.service,
    required this.onPicked,
  });

  @override
  State<_ProjectSiteDropdown> createState() => _ProjectSiteDropdownState();
}

class _ProjectSiteDropdownState extends State<_ProjectSiteDropdown> {
  bool _loading = true;
  String? _error;
  List<ProjectSite> _sites = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await widget.service.listSites(projectId: widget.projectId);
      if (!mounted) return;
      setState(() => _sites = data);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addSite() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사이트 추가'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '고객사명 입력'),
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('추가')),
        ],
      ),
    );
    final v = (name ?? '').trim();
    if (v.isEmpty) return;
    await widget.service.createSite(
        projectId: widget.projectId, name: v);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('사이트 선택',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface)),
            const Spacer(),
            IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: '새로고침'),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                tooltip: '닫기'),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _addSite,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Row(children: [
              Icon(Icons.add, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text('사이트 추가',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: cs.primary)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!,
                style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child:
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_sites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text('등록된 사이트가 없습니다.',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.55))),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _sites.length,
              separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.25)),
              itemBuilder: (ctx, i) {
                final site = _sites[i];
                return ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(site.name,
                      style: const TextStyle(fontSize: 13)),
                  onTap: () => widget.onPicked(site.name),
                  trailing: IconButton(
                    icon: Icon(Icons.close, size: 18, color: cs.error),
                    tooltip: '삭제',
                    onPressed: () async {
                      await widget.service.deleteSite(siteId: site.id);
                      await _load();
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────
// 필터 아이콘 버튼
// ────────────────────────────────────────────

class _FilterIconButton extends StatelessWidget {
  final bool isActive;
  final Color color;
  final void Function(Rect rect)? onTap;

  const _FilterIconButton(
      {required this.isActive, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 15,
        splashRadius: 14,
        icon: Icon(Icons.filter_list,
            color: isActive ? color : color.withValues(alpha: 0.55),
            size: 15),
        onPressed: () {
          final box = context.findRenderObject() as RenderBox;
          final offset = box.localToGlobal(Offset.zero);
          final rect = Rect.fromLTWH(
              offset.dx, offset.dy, box.size.width, box.size.height);
          onTap?.call(rect);
        },
        tooltip: '필터',
      ),
    );
  }
}
