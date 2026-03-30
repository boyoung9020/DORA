import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/project_provider.dart';
import '../../utils/avatar_color.dart';
import '../../widgets/glass_container.dart';
import '../../models/patch.dart';
import '../../services/patch_service.dart';
import '../../models/project_site.dart';
import '../../services/project_site_service.dart';

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
  String? _error;
  String? _currentProjectId;
  List<Patch> _patches = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final projectId = context.watch<ProjectProvider>().currentProject?.id;
    if (projectId != _currentProjectId) {
      _currentProjectId = projectId;
      if (projectId != null) {
        _loadPatches(projectId);
      } else {
        setState(() => _patches = []);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 태그 문자열로 결정론적 색상 반환
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

  /// 현재 프로젝트의 task site_tags + 패치 데이터 site 값의 합집합
  List<String> _getAllSiteTags(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final projectProvider = context.read<ProjectProvider>();
    final projectId = projectProvider.currentProject?.id;

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
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
              if (isSelected) {
                _siteFilters.remove(site);
              } else {
                _siteFilters.add(site);
              }
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

  void _showAddPatchDialog(
      BuildContext context, List<String> allSites, ColorScheme colorScheme) {
    final projectId = _currentProjectId;
    if (projectId == null) return;

    final siteCtrl = TextEditingController();
    final dateCtrl = TextEditingController();
    final versionCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
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
                    // 순서: 사이트 → 날짜 → 버전 → 패치 내용
                    Text('사이트',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.6))),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await _showProjectSiteDropdown(
                          context: dialogContext,
                          projectId: projectId,
                          colorScheme: colorScheme,
                        );
                        if (picked != null) {
                          setDialogState(() => siteCtrl.text = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        child: Row(
                          children: [
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
                                      : colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.arrow_drop_down,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.6)),
                          ],
                        ),
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
                        isDense: true,
                      ),
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
                    const SizedBox(height: 10),
                    _dialogField('패치 내용', contentCtrl, '패치 내용을 입력하세요'),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('취소'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  final site = siteCtrl.text.trim();
                                  final content = contentCtrl.text.trim();
                                  if (site.isEmpty ||
                                      selectedDate == null ||
                                      content.isEmpty) {
                                    return;
                                  }
                                  try {
                                    setState(() => _isLoading = true);
                                    await _service.createPatch(
                                      projectId: projectId,
                                      site: site,
                                      patchDate: selectedDate!,
                                      version: versionCtrl.text.trim(),
                                      content: content,
                                    );
                                    if (!mounted) return;
                                    await _loadPatches(projectId);
                                    if (!mounted) return;
                                    Navigator.pop(dialogContext);
                                  } finally {
                                    if (mounted) setState(() => _isLoading = false);
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
        });
      },
    );
  }

  Widget _dialogField(
      String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final allSites = _getAllSiteTags(context);
    final filteredData = _getFilteredData();
    final hasFilters = _siteFilters.isNotEmpty || _searchQuery.isNotEmpty;

    return SingleChildScrollView(
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
            // ─── 헤더
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search,
                            size: 18,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4)),
                        hintText: '내용, 버전, 사이트 검색...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.4)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: colorScheme.outlineVariant),
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
                          color: colorScheme.onSurface.withValues(alpha: 0.5))),
                  const Spacer(),
                  if (_isLoading)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                  if (hasFilters)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _siteFilters.clear();
                          _searchController.clear();
                        });
                      },
                      icon: const Icon(Icons.filter_alt_off, size: 16),
                      label: const Text('필터 초기화'),
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.primary,
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () =>
                        _showAddPatchDialog(context, allSites, colorScheme),
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
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(color: colorScheme.error, fontSize: 12),
                ),
              ),
            // ─── 테이블 헤더
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              color: colorScheme.onSurface.withValues(alpha: 0.03),
              child: Row(
                children: [
                  // 사이트 (filterable)
                  SizedBox(
                    width: 110,
                    child: _buildSiteHeader(context, colorScheme, allSites),
                  ),
                  // 날짜 (sortable)
                  SizedBox(
                    width: 130,
                    child: _buildDateHeader(context, colorScheme),
                  ),
                  // 버전
                  const SizedBox(
                    width: 120,
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('버전',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  // 내용
                  const Expanded(
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text('내용',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            // ─── 테이블 본문
            if (filteredData.isEmpty && !_isLoading)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text('패치 내역이 없습니다.',
                    style: TextStyle(
                        color: colorScheme.onSurface.withValues(alpha: 0.5))),
              )
            else
              ...filteredData.map((row) {
                final site = row.site;
                final siteColor = site.isNotEmpty ? _tagColor(site) : Colors.grey;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
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
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: site.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: siteColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(site,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: siteColor)),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                      // 날짜
                      SizedBox(
                        width: 130,
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
                        width: 120,
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 8),
                          child: row.version.isNotEmpty
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Text(row.version,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: colorScheme.onSurface
                                              .withValues(alpha: 0.7))),
                                )
                              : const SizedBox.shrink(),
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
                );
              }),
          ],
        ),
      ),
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
                _sortDescending ? Icons.arrow_downward : Icons.arrow_upward,
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
      builder: (dialogContext) {
        return Dialog(
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
        );
      },
    );
  }
}

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
      final data = await widget.service.listSites(projectId: widget.projectId);
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
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    final v = (name ?? '').trim();
    if (v.isEmpty) return;
    await widget.service.createSite(projectId: widget.projectId, name: v);
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
            Text(
              '사이트 선택',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '새로고침',
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 18),
              tooltip: '닫기',
            ),
          ],
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: _addSite,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.add, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  '사이트 추가',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child:
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (_sites.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              '등록된 사이트가 없습니다.',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _sites.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.25),
              ),
              itemBuilder: (ctx, i) {
                final site = _sites[i];
                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(site.name, style: const TextStyle(fontSize: 13)),
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

// ─── 필터 아이콘 버튼

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
            color: isActive ? color : color.withValues(alpha: 0.55), size: 15),
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
