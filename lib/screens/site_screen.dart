import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/patch.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../utils/avatar_color.dart';
import '../models/site_detail.dart';
import '../services/patch_service.dart';
import '../services/site_detail_service.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  final SiteDetailService _service = SiteDetailService();
  final PatchService _patchService = PatchService();

  bool _isLoading = false;
  String? _error;
  List<SiteDetail> _sites = [];
  SiteDetail? _selectedSite;
  String? _addProjectId;
  List<Patch> _patches = [];
  bool _patchesLoading = false;
  String? _lastPatchSiteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSites());
  }

  Future<void> _loadSites() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _service.listSites();
      if (!mounted) return;
      setState(() {
        _sites = data;
        if (_selectedSite == null && data.isNotEmpty) _selectedSite = data.first;
      });
      if (_selectedSite != null) _loadPatches(_selectedSite!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _selectSite(SiteDetail site) {
    setState(() {
      _selectedSite = site;
      if (_lastPatchSiteId != site.id) {
        _patches = [];
      }
    });
    _loadPatches(site);
  }

  Future<void> _loadPatches(SiteDetail site) async {
    if (_lastPatchSiteId == site.id) return;
    _lastPatchSiteId = site.id;
    setState(() => _patchesLoading = true);
    try {
      final list = await _patchService.getPatchesBySite(siteName: site.name);
      if (!mounted) return;
      setState(() => _patches = list);
    } catch (_) {}
    if (mounted) setState(() => _patchesLoading = false);
  }

  Future<void> _deleteSite(SiteDetail site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사이트 삭제'),
        content: Text("'${site.name}' 사이트를 삭제하시겠습니까?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isLoading = true);
    try {
      await _service.deleteSite(siteId: site.id);
      if (!mounted) return;
      setState(() {
        _sites.removeWhere((s) => s.id == site.id);
        if (_selectedSite?.id == site.id) {
          _selectedSite = _sites.isNotEmpty ? _sites.first : null;
          _patches = [];
          _lastPatchSiteId = null;
        }
      });
      if (_selectedSite != null) _loadPatches(_selectedSite!);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _doCreateSite(String projectId, String name) async {
    if (name.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final created = await _service.createSite(projectId: projectId, name: name);
      if (!mounted) return;
      setState(() {
        _sites.add(created);
        _selectedSite = created;
        _patches = [];
        _lastPatchSiteId = null;
        _addProjectId = projectId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveServers(List<ServerInfo> servers) async {
    final site = _selectedSite; if (site == null) return;
    try {
      final updated = await _service.updateSite(
        siteId: site.id, name: site.name, description: site.description,
        servers: servers, databases: site.databases, services: site.services,
      );
      if (!mounted) return;
      setState(() {
        final idx = _sites.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) _sites[idx] = updated;
        _selectedSite = updated;
      });
    } catch (_) {}
  }

  Future<void> _saveDatabases(List<DatabaseInfo> databases) async {
    final site = _selectedSite; if (site == null) return;
    try {
      final updated = await _service.updateSite(
        siteId: site.id, name: site.name, description: site.description,
        servers: site.servers, databases: databases, services: site.services,
      );
      if (!mounted) return;
      setState(() {
        final idx = _sites.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) _sites[idx] = updated;
        _selectedSite = updated;
      });
    } catch (_) {}
  }

  Future<void> _saveServices(List<ServiceInfo> services) async {
    final site = _selectedSite; if (site == null) return;
    try {
      final updated = await _service.updateSite(
        siteId: site.id, name: site.name, description: site.description,
        servers: site.servers, databases: site.databases, services: services,
      );
      if (!mounted) return;
      setState(() {
        final idx = _sites.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) _sites[idx] = updated;
        _selectedSite = updated;
      });
    } catch (_) {}
  }

  void _showAddSiteDialog(ColorScheme colorScheme) {
    final projects = context.read<ProjectProvider>().projects;
    if (projects.isEmpty) return;
    String? selectedProjectId = _addProjectId ?? projects.first.id;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('새 사이트 추가', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 340,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Align(alignment: Alignment.centerLeft,
                  child: Text('프로젝트', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedProjectId,
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: projects.map((p) => DropdownMenuItem(value: p.id,
                    child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setDlgState(() => selectedProjectId = v),
              ),
              const SizedBox(height: 12),
              TextField(controller: ctrl, autofocus: true,
                  decoration: const InputDecoration(labelText: '사이트명', hintText: '예) 홍길동 회사',
                      border: OutlineInputBorder(), isDense: true),
                  onSubmitted: (_) async {
                    if (selectedProjectId == null) return;
                    await _doCreateSite(selectedProjectId!, ctrl.text.trim());
                    if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  }),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('취소')),
            FilledButton(
              onPressed: () async {
                if (selectedProjectId == null) return;
                await _doCreateSite(selectedProjectId!, ctrl.text.trim());
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final projects = context.watch<ProjectProvider>().projects;

    return Row(
      children: [
        // ── 왼쪽 사이드바
        _buildSidebar(colorScheme, projects),
        VerticalDivider(width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
        // ── 오른쪽 메인 패널
        Expanded(
          child: _isLoading && _sites.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _selectedSite == null
                  ? _buildEmptyState(colorScheme, projects)
                  : _buildDetailPanel(_selectedSite!, colorScheme, projects),
        ),
      ],
    );
  }

  // ── 사이드바 ──────────────────────────────────────────────
  Widget _buildSidebar(ColorScheme colorScheme, List<Project> projects) {
    return SizedBox(
      width: 232,
      child: Column(
        children: [
          // 사이드바 헤더
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Text('사이트',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface)),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: projects.isEmpty ? null : () => _showAddSiteDialog(colorScheme),
                  icon: Icon(Icons.add, size: 18, color: colorScheme.primary),
                  tooltip: '사이트 추가',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              color: colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Text(_error!,
                  style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 11)),
            ),
          // 사이트 목록
          Expanded(
            child: _sites.isEmpty && !_isLoading
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.dns_outlined, size: 36,
                          color: colorScheme.onSurface.withValues(alpha: 0.15)),
                      const SizedBox(height: 8),
                      Text('사이트 없음',
                          style: TextStyle(fontSize: 12,
                              color: colorScheme.onSurface.withValues(alpha: 0.35))),
                    ]),
                  )
                : ListView.builder(
                    itemCount: _sites.length,
                    itemBuilder: (_, i) => _buildSiteCard(_sites[i], colorScheme, projects),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(SiteDetail site, ColorScheme colorScheme, List<Project> projects) {
    final isSelected = _selectedSite?.id == site.id;
    final accent = AvatarColor.getColorForUser(site.name);
    final linked = projects.where((p) => site.projectIds.contains(p.id)).toList();

    return InkWell(
      onTap: () => _selectSite(site),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary.withValues(alpha: 0.07) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.18)),
          ),
        ),
        child: Row(
          children: [
            // 아바타
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Text(
                  site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: accent),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                          color: isSelected ? colorScheme.primary : colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  // 프로젝트 배지
                  if (linked.isNotEmpty)
                    Wrap(
                      spacing: 3,
                      children: linked.take(2).map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(p.name,
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: p.color),
                            overflow: TextOverflow.ellipsis),
                      )).toList(),
                    ),
                  const SizedBox(height: 3),
                  // 서버/DB 카운트
                  Row(
                    children: [
                      _sidebarChip(Icons.computer, '${site.servers.length}', colorScheme),
                      const SizedBox(width: 8),
                      _sidebarChip(Icons.storage, '${site.databases.length}', colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sidebarChip(IconData icon, String label, ColorScheme cs) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: cs.onSurface.withValues(alpha: 0.35)),
      const SizedBox(width: 2),
      Text(label,
          style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.45))),
    ]);
  }

  // ── 빈 상태 ──────────────────────────────────────────────
  Widget _buildEmptyState(ColorScheme colorScheme, List<Project> projects) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.dns_outlined, size: 54, color: colorScheme.onSurface.withValues(alpha: 0.13)),
      const SizedBox(height: 14),
      Text('사이트를 선택하세요',
          style: TextStyle(fontSize: 15, color: colorScheme.onSurface.withValues(alpha: 0.4))),
      const SizedBox(height: 4),
      Text('왼쪽에서 사이트를 선택하거나 새로 추가하세요.',
          style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withValues(alpha: 0.3))),
      if (projects.isNotEmpty) ...[
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _showAddSiteDialog(colorScheme),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('사이트 추가'),
        ),
      ],
    ]));
  }

  // ── 상세 패널 (2-패널) ───────────────────────────────────
  Widget _buildDetailPanel(SiteDetail site, ColorScheme colorScheme, List<Project> projects) {
    final accent = AvatarColor.getColorForUser(site.name);
    final linked = projects.where((p) => site.projectIds.contains(p.id)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 사이트 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: accent),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface)),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 5, runSpacing: 4,
                      children: linked.map((p) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: p.color.withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: p.color.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7,
                              decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                          const SizedBox(width: 5),
                          Text(p.name,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: p.color)),
                        ]),
                      )).toList(),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _deleteSite(site),
                icon: Icon(Icons.delete_outline, size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.35)),
                tooltip: '사이트 삭제',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        // ── 2열 본문
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 왼쪽: 서버/DB/서비스 (스크롤)
              Expanded(
                flex: 55,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ServerFlatSection(
                        key: ValueKey('srv_${site.id}'),
                        servers: site.servers,
                        colorScheme: colorScheme,
                        onSave: _saveServers,
                      ),
                      const SizedBox(height: 16),
                      _DatabaseEmbeddedSection(
                        key: ValueKey('db_${site.id}'),
                        databases: site.databases,
                        colorScheme: colorScheme,
                        onSave: _saveDatabases,
                      ),
                      const SizedBox(height: 16),
                      _ServiceEmbeddedSection(
                        key: ValueKey('svc_${site.id}'),
                        services: site.services,
                        colorScheme: colorScheme,
                        onSave: _saveServices,
                      ),
                    ],
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
              // 오른쪽: 패치 이력
              Expanded(
                flex: 45,
                child: _PatchHistoryView(
                  patches: _patches,
                  loading: _patchesLoading,
                  projects: projects,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════
// 서버 정보 섹션 (계정공유 + IP 목록)
// ═══════════════════════════════════════
class _ServerFlatSection extends StatefulWidget {
  final List<ServerInfo> servers;
  final ColorScheme colorScheme;
  final Future<void> Function(List<ServerInfo>) onSave;
  const _ServerFlatSection({super.key, required this.servers, required this.colorScheme, required this.onSave});
  @override State<_ServerFlatSection> createState() => _ServerFlatSectionState();
}

class _ServerFlatSectionState extends State<_ServerFlatSection> {
  static const _color = Colors.indigo;

  ServerInfo get _creds => widget.servers.isNotEmpty ? widget.servers.first : ServerInfo();

  Future<void> _editCredentials() async {
    final c = _creds;
    final ctrls = [c.username, c.password, c.gpu, c.mount, c.note]
        .map((v) => TextEditingController(text: v)).toList();
    final labels = ['ID', '비밀번호', 'GPU', '마운트 경로', '비고'];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정 정보 편집', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: ctrls[i], autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: labels[i], border: const OutlineInputBorder(), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    final vals = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true) return;
    final updated = widget.servers.map((s) => ServerInfo(
      ip: s.ip, username: vals[0], password: vals[1], gpu: vals[2], mount: vals[3], note: vals[4],
    )).toList();
    await widget.onSave(updated);
  }

  Future<void> _addIp() async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 IP 추가', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            labelText: 'IP 주소', hintText: '예) 10.158.108.111',
            border: OutlineInputBorder(), isDense: true,
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    final ip = ctrl.text.trim();
    ctrl.dispose();
    if (result != true || ip.isEmpty) return;
    final c = _creds;
    await widget.onSave([...widget.servers,
      ServerInfo(ip: ip, username: c.username, password: c.password, gpu: c.gpu, mount: c.mount, note: c.note)]);
  }

  Future<void> _removeIp(String ip) async {
    await widget.onSave(widget.servers.where((s) => s.ip != ip).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final c = _creds;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.computer_outlined, size: 15, color: _color)),
            const SizedBox(width: 10),
            const Text('서버 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color)),
            const Spacer(),
            if (widget.servers.isNotEmpty)
              IconButton(
                onPressed: _editCredentials,
                icon: Icon(Icons.edit_outlined, size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
                tooltip: '계정 정보 편집', padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
          ]),
        ),
        // 계정 정보 행
        if (widget.servers.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Text('서버가 없습니다.', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35))),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (c.username.isNotEmpty) _infoRow(Icons.person_outline, 'ID', c.username, cs),
              if (c.password.isNotEmpty) _infoRow(Icons.lock_outline, '비밀번호', '••••••••', cs),
              if (c.gpu.isNotEmpty) _infoRow(Icons.memory_outlined, 'GPU', c.gpu, cs),
              if (c.mount.isNotEmpty) _infoRow(Icons.folder_outlined, 'Mount', c.mount, cs),
              if (c.note.isNotEmpty) _infoRow(Icons.notes_outlined, '비고', c.note, cs),
              if (c.username.isEmpty && c.password.isEmpty && c.gpu.isEmpty && c.mount.isEmpty)
                Text('계정 정보를 입력하세요 (편집 버튼)',
                    style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.3))),
            ]),
          ),
        // IP 목록
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('서버 IP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: _color.withValues(alpha: 0.6), letterSpacing: 0.3)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              ...widget.servers.map((s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _color.withValues(alpha: 0.18)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.ip.isEmpty ? '(미설정)' : s.ip,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _color, fontFamily: 'monospace')),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => _removeIp(s.ip),
                    child: Icon(Icons.close, size: 12, color: cs.onSurface.withValues(alpha: 0.4)),
                  ),
                ]),
              )),
              InkWell(
                onTap: _addIp,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _color.withValues(alpha: 0.3)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 13, color: _color.withValues(alpha: 0.6)),
                    const SizedBox(width: 3),
                    Text('IP 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: _color.withValues(alpha: 0.6))),
                  ]),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: _color.withValues(alpha: 0.55)),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.9))),
        ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.6))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// DB 섹션 (임베드용)
// ═══════════════════════════════════════
class _DatabaseEmbeddedSection extends StatefulWidget {
  final List<DatabaseInfo> databases;
  final ColorScheme colorScheme;
  final Future<void> Function(List<DatabaseInfo>) onSave;
  const _DatabaseEmbeddedSection({super.key, required this.databases, required this.colorScheme, required this.onSave});
  @override State<_DatabaseEmbeddedSection> createState() => _DatabaseEmbeddedSectionState();
}

class _DatabaseEmbeddedSectionState extends State<_DatabaseEmbeddedSection> {
  static const _color = Colors.teal;

  Future<void> _openDialog({DatabaseInfo? existing}) async {
    final isEdit = existing != null;
    final ctrls = [
      existing?.name ?? '', existing?.type ?? '', existing?.user ?? '',
      existing?.password ?? '', existing?.ip ?? '', existing?.port ?? '', existing?.note ?? '',
    ].map((v) => TextEditingController(text: v)).toList();
    final labels = ['DB명 *', '종류', '계정', '비밀번호', 'IP 주소', '포트', '비고'];
    final hints = ['예) face_milvus_only', '예) Milvus', 'face_milvus_only', '', '10.158.108.200', '19530', ''];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'DB 편집' : 'DB 추가',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: ctrls[i], autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: labels[i], hintText: hints[i],
                  border: const OutlineInputBorder(), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? '저장' : '추가')),
        ],
      ),
    );
    final values = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true || values[0].isEmpty) return;
    final db = DatabaseInfo(name: values[0], type: values[1], user: values[2],
        password: values[3], ip: values[4], port: values[5], note: values[6]);
    if (isEdit) {
      final list = widget.databases.toList();
      final idx = list.indexOf(existing);
      if (idx >= 0) list[idx] = db;
      await widget.onSave(list);
    } else {
      await widget.onSave([...widget.databases, db]);
    }
  }

  Future<void> _delete(DatabaseInfo db) async {
    await widget.onSave(widget.databases.where((d) => d != db).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.storage_outlined, size: 15, color: _color)),
            const SizedBox(width: 10),
            const Text('DB 정보', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color)),
            const Spacer(),
            InkWell(
              onTap: () => _openDialog(),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 14, color: _color),
                  const SizedBox(width: 3),
                  const Text('추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
                ]),
              ),
            ),
          ]),
        ),
        // DB 카드 목록
        if (widget.databases.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('등록된 DB가 없습니다.',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.35))),
          )
        else
          ...widget.databases.asMap().entries.map((e) {
            final db = e.value;
            final isLast = e.key == widget.databases.length - 1;
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(db.name.isEmpty ? '(이름 없음)' : db.name,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _color)),
                        if (db.type.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(db.type,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                                    color: _color.withValues(alpha: 0.8))),
                          ),
                        ],
                      ]),
                      const SizedBox(height: 6),
                      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (db.ip.isNotEmpty || db.port.isNotEmpty)
                          _infoRow(Icons.dns_outlined, '접속',
                              [if (db.ip.isNotEmpty) db.ip, if (db.port.isNotEmpty) ':${db.port}'].join(''), cs),
                        if (db.user.isNotEmpty) _infoRow(Icons.person_outline, '계정', db.user, cs),
                        if (db.password.isNotEmpty) _infoRow(Icons.lock_outline, '비밀번호', '••••••••', cs),
                        if (db.note.isNotEmpty) _infoRow(Icons.notes_outlined, '비고', db.note, cs),
                      ]),
                    ]),
                  ),
                  Column(children: [
                    IconButton(
                      onPressed: () => _openDialog(existing: db),
                      icon: Icon(Icons.edit_outlined, size: 14, color: cs.onSurface.withValues(alpha: 0.4)),
                      tooltip: '편집', padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                    IconButton(
                      onPressed: () => _delete(db),
                      icon: Icon(Icons.delete_outline, size: 14, color: cs.error.withValues(alpha: 0.5)),
                      tooltip: '삭제', padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ]),
                ]),
              ),
              if (!isLast) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            ]);
          }),
      ]),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(icon, size: 14, color: _color.withValues(alpha: 0.55)),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.5))),
        ),
        Expanded(
          child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: cs.onSurface.withValues(alpha: 0.9))),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 서비스 섹션 (임베드용, IP 그룹)
// ═══════════════════════════════════════
class _ServiceEmbeddedSection extends StatefulWidget {
  final List<ServiceInfo> services;
  final ColorScheme colorScheme;
  final Future<void> Function(List<ServiceInfo>) onSave;
  const _ServiceEmbeddedSection({super.key, required this.services, required this.colorScheme, required this.onSave});
  @override State<_ServiceEmbeddedSection> createState() => _ServiceEmbeddedSectionState();
}

class _ServiceEmbeddedSectionState extends State<_ServiceEmbeddedSection> {
  static const _color = Colors.deepPurple;

  List<String> _serverIps() {
    final seen = <String>{};
    final result = <String>[];
    for (final s in widget.services) {
      final ip = s.serverIp.trim();
      if (!seen.contains(ip)) { seen.add(ip); result.add(ip); }
    }
    return result;
  }

  List<ServiceInfo> _servicesFor(String ip) =>
      widget.services.where((s) => s.serverIp.trim() == ip).toList();

  Future<void> _addServer() async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 IP 추가', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl, autofocus: true,
          decoration: const InputDecoration(
            labelText: '서버 IP', hintText: '예) 10.158.108.111',
            border: OutlineInputBorder(), isDense: true,
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    final ip = ctrl.text.trim();
    ctrl.dispose();
    if (result != true || ip.isEmpty) return;
    await widget.onSave([...widget.services, ServiceInfo(serverIp: ip)]);
  }

  Future<void> _addService(String serverIp) async {
    final ctrls = [TextEditingController(), TextEditingController(),
                   TextEditingController(), TextEditingController()];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$serverIp 서비스 추가', style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(ctrls[0], '서비스명', '예) Face'),
            const SizedBox(height: 8),
            _dialogField(ctrls[1], 'Workers', '예) 10'),
            const SizedBox(height: 8),
            _dialogField(ctrls[2], 'GPU 사용량', '예) 33734'),
            const SizedBox(height: 8),
            _dialogField(ctrls[3], '비고', ''),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    final vals = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true) return;
    await widget.onSave([...widget.services,
      ServiceInfo(serverIp: serverIp, name: vals[0], workers: vals[1], gpuUsage: vals[2], note: vals[3])]);
  }

  Widget _dialogField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label, hintText: hint,
          border: const OutlineInputBorder(), isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
      style: const TextStyle(fontSize: 13),
    );
  }

  Future<void> _deleteService(ServiceInfo target) async {
    await widget.onSave(widget.services.where((s) => s != target).toList());
  }

  Future<void> _deleteServer(String ip) async {
    await widget.onSave(widget.services.where((s) => s.serverIp.trim() != ip).toList());
  }

  @override
  Widget build(BuildContext context) {
    final ips = _serverIps();
    final cs = widget.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(width: 28, height: 28,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(7)),
              child: const Icon(Icons.apps_outlined, size: 15, color: _color)),
            const SizedBox(width: 10),
            const Text('서비스', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color)),
            const Spacer(),
            InkWell(
              onTap: _addServer,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.add, size: 14, color: _color),
                  const SizedBox(width: 3),
                  const Text('서버 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
                ]),
              ),
            ),
          ]),
        ),
        if (ips.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('등록된 서비스가 없습니다.',
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.35))),
          )
        else
          ...ips.asMap().entries.map((e) {
            final ip = e.value;
            final isLast = e.key == ips.length - 1;
            final svcs = _servicesFor(ip);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // 서버 IP 행
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                color: cs.onSurface.withValues(alpha: 0.025),
                child: Row(children: [
                  Icon(Icons.computer_outlined, size: 13, color: _color.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Text(ip.isEmpty ? '(IP 없음)' : ip,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: _color, fontFamily: 'monospace')),
                  const Spacer(),
                  InkWell(
                    onTap: () => _addService(ip),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add, size: 12, color: _color.withValues(alpha: 0.6)),
                      const SizedBox(width: 3),
                      Text('서비스 추가', style: TextStyle(fontSize: 11,
                          fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.6))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _deleteServer(ip),
                    child: Icon(Icons.delete_outline, size: 14, color: cs.onSurface.withValues(alpha: 0.3)),
                  ),
                ]),
              ),
              // 서비스 행들 (_ServiceRow 재사용)
              ...svcs.map((svc) => _ServiceRow(
                svc: svc,
                colorScheme: cs,
                accentColor: _color,
                onDelete: () => _deleteService(svc),
                onChanged: (updated) {
                  final list = widget.services.toList();
                  final idx = list.indexOf(svc);
                  if (idx >= 0) list[idx] = updated;
                  widget.onSave(list);
                },
              )),
              if (!isLast) Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),
            ]);
          }),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 패치 이력 뷰
// ═══════════════════════════════════════
class _PatchHistoryView extends StatelessWidget {
  final List<Patch> patches;
  final bool loading;
  final List<Project> projects;
  final ColorScheme colorScheme;

  const _PatchHistoryView({
    required this.patches,
    required this.loading,
    required this.projects,
    required this.colorScheme,
  });

  // 연도별 그룹화
  Map<int, List<Patch>> _groupByYear() {
    final map = <int, List<Patch>>{};
    for (final p in patches) {
      (map[p.patchDate.year] ??= []).add(p);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (patches.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_outlined, size: 40,
              color: colorScheme.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 10),
          Text('패치 이력이 없습니다.',
              style: TextStyle(fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.35))),
        ]),
      );
    }

    final grouped = _groupByYear();
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a)); // 최신 연도 위

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.25))),
          ),
          child: Row(children: [
            Icon(Icons.history_outlined, size: 16, color: colorScheme.primary.withValues(alpha: 0.7)),
            const SizedBox(width: 8),
            Text('패치 내역',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${patches.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: colorScheme.primary)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            itemCount: years.length,
            itemBuilder: (_, i) {
              final year = years[i];
              final yearPatches = grouped[year]!;
              return _YearGroup(
                year: year,
                patches: yearPatches,
                projects: projects,
                colorScheme: colorScheme,
                isLast: i == years.length - 1,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _YearGroup extends StatelessWidget {
  final int year;
  final List<Patch> patches;
  final List<Project> projects;
  final ColorScheme colorScheme;
  final bool isLast;

  const _YearGroup({
    required this.year,
    required this.patches,
    required this.projects,
    required this.colorScheme,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 타임라인 축
        SizedBox(
          width: 52,
          child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('$year',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: cs.primary)),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: patches.length * 56.0 + 8,
                color: cs.primary.withValues(alpha: 0.12),
              ),
          ]),
        ),
        const SizedBox(width: 12),
        // 패치 목록
        Expanded(
          child: Column(
            children: patches.map((patch) {
              final proj = projects.where((p) => p.id == patch.projectId).firstOrNull;
              return _PatchTimelineItem(
                patch: patch,
                proj: proj,
                colorScheme: cs,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _PatchTimelineItem extends StatelessWidget {
  final Patch patch;
  final Project? proj;
  final ColorScheme colorScheme;

  const _PatchTimelineItem({
    required this.patch,
    required this.proj,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    final statusColor = patch.status == 'done'
        ? const Color(0xFF2E7D32)
        : patch.status == 'in_progress'
            ? Colors.orange
            : cs.onSurface.withValues(alpha: 0.4);
    final statusLabel = patch.status == 'done' ? '완료'
        : patch.status == 'in_progress' ? '진행 중' : '대기';

    // 날짜에서 월.일만 표시
    final md = '${patch.patchDate.month.toString().padLeft(2, '0')}.${patch.patchDate.day.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Row(children: [
          // 날짜
          SizedBox(
            width: 34,
            child: Text(md,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    color: cs.onSurface.withValues(alpha: 0.4))),
          ),
          // 프로젝트 배지 (날짜 바로 뒤)
          if (proj != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: proj!.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(proj!.name,
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: proj!.color)),
            ),
            const SizedBox(width: 6),
          ],
          // 버전 뱃지
          if (patch.version.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(patch.version,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: cs.primary)),
            ),
            const SizedBox(width: 8),
          ],
          // 내용
          Expanded(
            child: Text(patch.content,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: cs.onSurface.withValues(alpha: 0.9)),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          // 상태
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(statusLabel,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 서버 카드뷰
// ═══════════════════════════════════════
class _ServerCardView extends StatefulWidget {
  final List<ServerInfo> servers;
  final ColorScheme colorScheme;
  final Future<void> Function(List<ServerInfo>) onSave;
  const _ServerCardView({super.key, required this.servers, required this.colorScheme, required this.onSave});
  @override State<_ServerCardView> createState() => _ServerCardViewState();
}

class _ServerCardViewState extends State<_ServerCardView> {
  static const _color = Colors.indigo;

  Future<void> _addServer() async {
    final ctrls = List.generate(6, (_) => TextEditingController());
    final labels = ['IP 주소 *', 'ID', '비밀번호', 'GPU', '마운트 경로', '비고'];
    final hints = ['예) 10.158.108.111', 'gemisoadmin', 'Nps@mbc!23', 'A6000(50G)', '/mnt/npsmain/root', ''];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 추가', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: ctrls[i],
                autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: labels[i], hintText: hints[i],
                  border: const OutlineInputBorder(), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    final values = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true || values[0].isEmpty) return;
    await widget.onSave([...widget.servers,
      ServerInfo(ip: values[0], username: values[1], password: values[2],
          gpu: values[3], mount: values[4], note: values[5])]);
  }

  Future<void> _deleteServer(ServerInfo srv) async {
    await widget.onSave(widget.servers.where((s) => s != srv).toList());
  }

  Future<void> _editServer(ServerInfo srv) async {
    final ctrls = [srv.ip, srv.username, srv.password, srv.gpu, srv.mount, srv.note]
        .map((v) => TextEditingController(text: v)).toList();
    final labels = ['IP 주소', 'ID', '비밀번호', 'GPU', '마운트 경로', '비고'];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 편집', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: ctrls[i],
                decoration: InputDecoration(
                  labelText: labels[i], border: const OutlineInputBorder(), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    final values = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true) return;
    final updated = widget.servers.toList();
    final idx = updated.indexOf(srv);
    if (idx >= 0) updated[idx] = ServerInfo(ip: values[0], username: values[1],
        password: values[2], gpu: values[3], mount: values[4], note: values[5]);
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Column(children: [
      Expanded(
        child: widget.servers.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.computer_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.15)),
                const SizedBox(height: 10),
                Text('등록된 서버가 없습니다.', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35))),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.servers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildServerCard(widget.servers[i], cs),
              ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)))),
        child: Row(children: [
          InkWell(
            onTap: _addServer,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add, size: 14, color: _color),
                const SizedBox(width: 4),
                Text('서버 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
              ]),
            ),
          ),
          const Spacer(),
          Text('서버 ${widget.servers.length}개',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.35))),
        ]),
      ),
    ]);
  }

  Widget _buildServerCard(ServerInfo srv, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.computer_outlined, size: 16, color: _color),
            ),
            const SizedBox(width: 10),
            Text(srv.ip.isEmpty ? '(IP 없음)' : srv.ip,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: _color, fontFamily: 'monospace')),
            const Spacer(),
            IconButton(
              onPressed: () => _editServer(srv),
              icon: Icon(Icons.edit_outlined, size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
              tooltip: '편집', padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: () => _deleteServer(srv),
              icon: Icon(Icons.delete_outline, size: 15, color: cs.error.withValues(alpha: 0.5)),
              tooltip: '삭제', padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),
        // 필드 그리드
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 12, runSpacing: 8, children: [
            if (srv.username.isNotEmpty) _infoChip(Icons.person_outline, 'ID', srv.username, cs),
            if (srv.password.isNotEmpty) _infoChip(Icons.lock_outline, '비밀번호', '••••••••', cs),
            if (srv.gpu.isNotEmpty) _infoChip(Icons.memory_outlined, 'GPU', srv.gpu, cs),
            if (srv.mount.isNotEmpty) _infoChip(Icons.folder_outlined, 'Mount', srv.mount, cs),
            if (srv.note.isNotEmpty) _infoChip(Icons.notes_outlined, '비고', srv.note, cs),
            if (srv.username.isEmpty && srv.password.isEmpty && srv.gpu.isEmpty && srv.mount.isEmpty && srv.note.isEmpty)
              Text('추가 정보 없음 (편집 버튼으로 입력)',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.3))),
          ]),
        ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.6))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// DB 카드뷰
// ═══════════════════════════════════════
class _DatabaseCardView extends StatefulWidget {
  final List<DatabaseInfo> databases;
  final ColorScheme colorScheme;
  final Future<void> Function(List<DatabaseInfo>) onSave;
  const _DatabaseCardView({super.key, required this.databases, required this.colorScheme, required this.onSave});
  @override State<_DatabaseCardView> createState() => _DatabaseCardViewState();
}

class _DatabaseCardViewState extends State<_DatabaseCardView> {
  static const _color = Colors.teal;

  Future<void> _openDialog({DatabaseInfo? existing}) async {
    final isEdit = existing != null;
    final ctrls = [
      existing?.name ?? '', existing?.type ?? '', existing?.user ?? '',
      existing?.password ?? '', existing?.ip ?? '', existing?.port ?? '', existing?.note ?? '',
    ].map((v) => TextEditingController(text: v)).toList();
    final labels = ['DB명 *', '종류', '계정', '비밀번호', 'IP 주소', '포트', '비고'];
    final hints = ['예) face_milvus_only', '예) Milvus', 'face_milvus_only', '', '10.158.108.200', '19530', ''];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'DB 편집' : 'DB 추가',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 340,
          child: Column(mainAxisSize: MainAxisSize.min,
            children: List.generate(7, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: ctrls[i], autofocus: i == 0,
                decoration: InputDecoration(
                  labelText: labels[i], hintText: hints[i],
                  border: const OutlineInputBorder(), isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            )),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(isEdit ? '저장' : '추가')),
        ],
      ),
    );
    final values = ctrls.map((c) => c.text.trim()).toList();
    for (final c in ctrls) { c.dispose(); }
    if (result != true || values[0].isEmpty) return;
    final db = DatabaseInfo(name: values[0], type: values[1], user: values[2],
        password: values[3], ip: values[4], port: values[5], note: values[6]);
    if (isEdit) {
      final list = widget.databases.toList();
      final idx = list.indexOf(existing);
      if (idx >= 0) list[idx] = db;
      await widget.onSave(list);
    } else {
      await widget.onSave([...widget.databases, db]);
    }
  }

  Future<void> _delete(DatabaseInfo db) async {
    await widget.onSave(widget.databases.where((d) => d != db).toList());
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Column(children: [
      Expanded(
        child: widget.databases.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.storage_outlined, size: 40, color: cs.onSurface.withValues(alpha: 0.15)),
                const SizedBox(height: 10),
                Text('등록된 DB가 없습니다.', style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.35))),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.databases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _buildDbCard(widget.databases[i], cs),
              ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.2)))),
        child: Row(children: [
          InkWell(
            onTap: () => _openDialog(),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add, size: 14, color: _color),
                const SizedBox(width: 4),
                const Text('DB 추가', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color)),
              ]),
            ),
          ),
          const Spacer(),
          Text('DB ${widget.databases.length}개',
              style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.35))),
        ]),
      ),
    ]);
  }

  Widget _buildDbCard(DatabaseInfo db, ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.storage_outlined, size: 16, color: _color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(db.name.isEmpty ? '(이름 없음)' : db.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _color)),
              if (db.type.isNotEmpty)
                Text(db.type, style: TextStyle(fontSize: 11, color: _color.withValues(alpha: 0.6))),
            ])),
            IconButton(
              onPressed: () => _openDialog(existing: db),
              icon: Icon(Icons.edit_outlined, size: 15, color: cs.onSurface.withValues(alpha: 0.4)),
              tooltip: '편집', padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              onPressed: () => _delete(db),
              icon: Icon(Icons.delete_outline, size: 15, color: cs.error.withValues(alpha: 0.5)),
              tooltip: '삭제', padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),
        // 접속 정보
        Padding(
          padding: const EdgeInsets.all(14),
          child: Wrap(spacing: 12, runSpacing: 8, children: [
            if (db.ip.isNotEmpty || db.port.isNotEmpty)
              _infoChip(Icons.dns_outlined, '접속',
                  [if (db.ip.isNotEmpty) db.ip, if (db.port.isNotEmpty) ':${db.port}'].join(''), cs),
            if (db.user.isNotEmpty) _infoChip(Icons.person_outline, '계정', db.user, cs),
            if (db.password.isNotEmpty) _infoChip(Icons.lock_outline, '비밀번호', '••••••••', cs),
            if (db.note.isNotEmpty) _infoChip(Icons.notes_outlined, '비고', db.note, cs),
            if (db.ip.isEmpty && db.user.isEmpty && db.password.isEmpty && db.note.isEmpty)
              Text('접속 정보 없음 (편집 버튼으로 입력)',
                  style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.3))),
          ]),
        ),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, String value, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _color.withValues(alpha: 0.12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: _color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _color.withValues(alpha: 0.6))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: cs.onSurface.withValues(alpha: 0.85))),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════
// 공용 인라인 편집 테이블 베이스
// ═══════════════════════════════════════
abstract class _InlineTable<T> extends StatefulWidget {
  final SiteDetail site;
  final ColorScheme colorScheme;
  const _InlineTable({super.key, required this.site, required this.colorScheme});
}

abstract class _InlineTableState<T, W extends _InlineTable<T>> extends State<W> {
  List<List<TextEditingController>> _ctrls = [];
  List<TextEditingController> _newRowCtrls = [];
  bool _addingRow = false;
  Timer? _saveTimer;

  Color get color;
  IconData get icon;
  String get title;
  List<String> get columns;
  List<double> get colWidths; // 0 = flex

  List<T> getItems();
  List<String> itemToStrings(T item);
  T stringsToItem(List<String> values);
  Future<void> Function(List<T>) get onSave;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  @override
  void didUpdateWidget(W old) {
    super.didUpdateWidget(old);
    if (old.site != widget.site) _initControllers();
  }

  void _initControllers() {
    for (final row in _ctrls) { for (final c in row) { c.dispose(); } }
    _ctrls = getItems().map((item) =>
        itemToStrings(item).map((v) => TextEditingController(text: v)).toList()
    ).toList();
  }

  void _scheduleSave(int rowIndex) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () => _saveRow(rowIndex));
  }

  Future<void> _saveRow(int rowIndex) async {
    if (rowIndex >= _ctrls.length) return;
    final values = _ctrls[rowIndex].map((c) => c.text.trim()).toList();
    final items = List<T>.from(getItems());
    items[rowIndex] = stringsToItem(values);
    await onSave(items);
  }

  Future<void> _deleteRow(int rowIndex) async {
    _saveTimer?.cancel();
    final items = List<T>.from(getItems())..removeAt(rowIndex);
    for (final c in _ctrls[rowIndex]) { c.dispose(); }
    _ctrls.removeAt(rowIndex);
    await onSave(items);
  }

  void _startAddRow() {
    setState(() {
      _newRowCtrls = List.generate(columns.length, (_) => TextEditingController());
      _addingRow = true;
    });
  }

  Future<void> _commitNewRow() async {
    final values = _newRowCtrls.map((c) => c.text.trim()).toList();
    if (values.every((v) => v.isEmpty)) {
      _cancelNewRow();
      return;
    }
    final items = List<T>.from(getItems())..add(stringsToItem(values));
    _ctrls.add(values.map((v) => TextEditingController(text: v)).toList());
    for (final c in _newRowCtrls) { c.dispose(); }
    setState(() => _addingRow = false);
    await onSave(items);
  }

  void _cancelNewRow() {
    for (final c in _newRowCtrls) { c.dispose(); }
    setState(() => _addingRow = false);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    for (final row in _ctrls) { for (final c in row) { c.dispose(); } }
    if (_addingRow) { for (final c in _newRowCtrls) { c.dispose(); } }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildColHeader(),
        Expanded(child: _buildBody()),
        _buildFooter(),
      ],
    );
  }

  Widget _buildColHeader() {
    return Container(
      color: color.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        ...List.generate(columns.length, (i) {
          final cell = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            child: Text(columns[i],
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color.withValues(alpha: 0.7),
                    letterSpacing: 0.3)),
          );
          return colWidths[i] == 0
              ? Expanded(child: cell)
              : SizedBox(width: colWidths[i], child: cell);
        }),
        const SizedBox(width: 36),
      ]),
    );
  }

  Widget _buildBody() {
    final items = getItems();
    return ListView.separated(
      itemCount: items.length + (_addingRow ? 1 : 0),
      separatorBuilder: (_, __) => Divider(
          height: 1, color: widget.colorScheme.outlineVariant.withValues(alpha: 0.2)),
      itemBuilder: (ctx, i) {
        if (_addingRow && i == items.length) return _buildNewRow();
        return _buildDataRow(i);
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(
            color: widget.colorScheme.outlineVariant.withValues(alpha: 0.2))),
      ),
      child: Row(children: [
        InkWell(
          onTap: _addingRow ? null : _startAddRow,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14,
                  color: _addingRow ? color.withValues(alpha: 0.3) : color),
              const SizedBox(width: 4),
              Text('행 추가',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _addingRow ? color.withValues(alpha: 0.3) : color)),
            ]),
          ),
        ),
        const Spacer(),
        Text('${getItems().length}행',
            style: TextStyle(
                fontSize: 11,
                color: widget.colorScheme.onSurface.withValues(alpha: 0.35))),
      ]),
    );
  }

  Widget _buildDataRow(int rowIndex) {
    if (rowIndex >= _ctrls.length) return const SizedBox.shrink();
    return _InlineRow(
      controllers: _ctrls[rowIndex],
      colWidths: colWidths,
      colorScheme: widget.colorScheme,
      accentColor: color,
      onChange: (_) => _scheduleSave(rowIndex),
      onDelete: () => _deleteRow(rowIndex),
    );
  }

  Widget _buildNewRow() {
    return Container(
      color: color.withValues(alpha: 0.04),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        ...List.generate(columns.length, (i) {
          final cell = _InlineCell(
            controller: _newRowCtrls[i],
            accentColor: color,
            colorScheme: widget.colorScheme,
            autofocus: i == 0,
            onSubmitted: (_) {
              if (i < columns.length - 1) {
                FocusScope.of(context).nextFocus();
              } else {
                _commitNewRow();
              }
            },
          );
          return colWidths[i] == 0 ? Expanded(child: cell) : SizedBox(width: colWidths[i], child: cell);
        }),
        SizedBox(
          width: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 15,
            icon: Icon(Icons.check, color: color),
            onPressed: _commitNewRow,
            tooltip: '확인',
          ),
        ),
      ]),
    );
  }
}

// ── 인라인 행
class _InlineRow extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<double> colWidths;
  final ColorScheme colorScheme;
  final Color accentColor;
  final void Function(String) onChange;
  final Future<void> Function() onDelete;

  const _InlineRow({
    required this.controllers,
    required this.colWidths,
    required this.colorScheme,
    required this.accentColor,
    required this.onChange,
    required this.onDelete,
  });

  @override
  State<_InlineRow> createState() => _InlineRowState();
}

class _InlineRowState extends State<_InlineRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: _hovered ? widget.accentColor.withValues(alpha: 0.04) : Colors.transparent,
        child: Row(children: [
          ...List.generate(widget.controllers.length, (i) {
            final cell = _InlineCell(
              controller: widget.controllers[i],
              accentColor: widget.accentColor,
              colorScheme: widget.colorScheme,
              onChange: widget.onChange,
            );
            return widget.colWidths[i] == 0
                ? Expanded(child: cell)
                : SizedBox(width: widget.colWidths[i], child: cell);
          }),
          SizedBox(
            width: 36,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: Icon(Icons.delete_outline,
                    color: widget.colorScheme.error.withValues(alpha: 0.6)),
                onPressed: () async => await widget.onDelete(),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 인라인 셀
class _InlineCell extends StatefulWidget {
  final TextEditingController controller;
  final Color accentColor;
  final ColorScheme colorScheme;
  final void Function(String)? onChange;
  final void Function(String)? onSubmitted;
  final bool autofocus;

  const _InlineCell({
    required this.controller,
    required this.accentColor,
    required this.colorScheme,
    this.onChange,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  State<_InlineCell> createState() => _InlineCellState();
}

class _InlineCellState extends State<_InlineCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(
            color: _focused ? widget.accentColor.withValues(alpha: 0.5) : Colors.transparent,
            width: 1.5,
          )),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              autofocus: widget.autofocus,
              onChanged: widget.onChange,
              onSubmitted: widget.onSubmitted,
              style: TextStyle(
                  fontSize: 12,
                  color: widget.colorScheme.onSurface.withValues(alpha: 0.85)),
              decoration: InputDecoration(
                hintText: widget.controller.text.isEmpty && !_focused ? '—' : null,
                hintStyle: TextStyle(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.25),
                    fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
              ),
            ),
          ),
          if (widget.controller.text.isNotEmpty && _focused)
            InkWell(
              onTap: () => Clipboard.setData(ClipboardData(text: widget.controller.text)),
              child: Icon(Icons.copy_outlined, size: 11,
                  color: widget.colorScheme.onSurface.withValues(alpha: 0.35)),
            ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════
// 서버 테이블
// ═══════════════════════════════════════
class _ServerTable extends _InlineTable<ServerInfo> {
  final Future<void> Function(List<ServerInfo>) onSave;
  const _ServerTable({super.key, required super.site, required super.colorScheme, required this.onSave});
  @override State<_ServerTable> createState() => _ServerTableState();
}

class _ServerTableState extends _InlineTableState<ServerInfo, _ServerTable> {
  @override Color get color => Colors.indigo;
  @override IconData get icon => Icons.computer_outlined;
  @override String get title => '서버 정보';
  @override List<String> get columns => ['IP 주소', 'ID', '비밀번호', 'GPU', '마운트 경로', '비고'];
  @override List<double> get colWidths => [145, 100, 115, 80, 140, 0];
  @override List<ServerInfo> getItems() => widget.site.servers;
  @override List<String> itemToStrings(ServerInfo i) => [i.ip, i.username, i.password, i.gpu, i.mount, i.note];
  @override ServerInfo stringsToItem(List<String> v) =>
      ServerInfo(ip: v[0], username: v[1], password: v[2], gpu: v[3], mount: v[4], note: v[5]);
  @override Future<void> Function(List<ServerInfo>) get onSave => widget.onSave;
}

// ═══════════════════════════════════════
// DB 테이블
// ═══════════════════════════════════════
class _DatabaseTable extends _InlineTable<DatabaseInfo> {
  final Future<void> Function(List<DatabaseInfo>) onSave;
  const _DatabaseTable({super.key, required super.site, required super.colorScheme, required this.onSave});
  @override State<_DatabaseTable> createState() => _DatabaseTableState();
}

class _DatabaseTableState extends _InlineTableState<DatabaseInfo, _DatabaseTable> {
  @override Color get color => Colors.teal;
  @override IconData get icon => Icons.storage_outlined;
  @override String get title => 'DB 정보';
  @override List<String> get columns => ['DB명', '종류', '계정', '비밀번호', 'IP 주소', '포트', '비고'];
  @override List<double> get colWidths => [110, 90, 100, 115, 140, 60, 0];
  @override List<DatabaseInfo> getItems() => widget.site.databases;
  @override List<String> itemToStrings(DatabaseInfo i) => [i.name, i.type, i.user, i.password, i.ip, i.port, i.note];
  @override DatabaseInfo stringsToItem(List<String> v) =>
      DatabaseInfo(name: v[0], type: v[1], user: v[2], password: v[3], ip: v[4], port: v[5], note: v[6]);
  @override Future<void> Function(List<DatabaseInfo>) get onSave => widget.onSave;
}

// ═══════════════════════════════════════
// 서비스 테이블
// ═══════════════════════════════════════
class _ServiceTable extends _InlineTable<ServiceInfo> {
  final Future<void> Function(List<ServiceInfo>) onSave;
  const _ServiceTable({super.key, required super.site, required super.colorScheme, required this.onSave});
  @override State<_ServiceTable> createState() => _ServiceTableState();
}

class _ServiceTableState extends _InlineTableState<ServiceInfo, _ServiceTable> {
  @override Color get color => Colors.deepPurple;
  @override IconData get icon => Icons.apps_outlined;
  @override String get title => '서비스 정보';
  @override List<String> get columns => ['서비스명', '버전', '서버 IP', 'Workers', 'GPU 사용량', '비고'];
  @override List<double> get colWidths => [110, 70, 145, 75, 110, 0];
  @override List<ServiceInfo> getItems() => widget.site.services;
  @override List<String> itemToStrings(ServiceInfo i) => [i.name, i.version, i.serverIp, i.workers, i.gpuUsage, i.note];
  @override ServiceInfo stringsToItem(List<String> v) =>
      ServiceInfo(name: v[0], version: v[1], serverIp: v[2], workers: v[3], gpuUsage: v[4], note: v[5]);
  @override Future<void> Function(List<ServiceInfo>) get onSave => widget.onSave;
}

// ═══════════════════════════════════════
// 서비스 그룹뷰 (서버 IP 기준 묶음)
// ═══════════════════════════════════════
class _ServiceGroupedView extends StatefulWidget {
  final List<ServiceInfo> services;
  final ColorScheme colorScheme;
  final Future<void> Function(List<ServiceInfo>) onSave;

  const _ServiceGroupedView({
    super.key,
    required this.services,
    required this.colorScheme,
    required this.onSave,
  });

  @override
  State<_ServiceGroupedView> createState() => _ServiceGroupedViewState();
}

class _ServiceGroupedViewState extends State<_ServiceGroupedView> {
  static const _color = Colors.deepPurple;

  // 서버 IP별로 그룹화
  List<String> _serverIps() {
    final seen = <String>{};
    final result = <String>[];
    for (final s in widget.services) {
      final ip = s.serverIp.trim();
      if (!seen.contains(ip)) {
        seen.add(ip);
        result.add(ip);
      }
    }
    return result;
  }

  List<ServiceInfo> _servicesFor(String ip) =>
      widget.services.where((s) => s.serverIp.trim() == ip).toList();

  Future<void> _addServer() async {
    final ctrl = TextEditingController();
    final ip = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('서버 IP 추가', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '서버 IP',
            hintText: '예) 10.158.108.111',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    if (ip == null || ip.isEmpty) return;
    // 빈 서비스 하나 추가해서 그룹 생성
    final updated = [...widget.services, ServiceInfo(serverIp: ip)];
    await widget.onSave(updated);
  }

  Future<void> _addService(String serverIp) async {
    final nameCtrls = [
      TextEditingController(), // 서비스명
      TextEditingController(), // workers
      TextEditingController(), // gpu
      TextEditingController(), // 비고
    ];
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$serverIp 서비스 추가', style: const TextStyle(fontSize: 14)),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _dialogField(nameCtrls[0], '서비스명', '예) Face'),
            const SizedBox(height: 8),
            _dialogField(nameCtrls[1], 'Workers', '예) 10'),
            const SizedBox(height: 8),
            _dialogField(nameCtrls[2], 'GPU 사용량', '예) 33734'),
            const SizedBox(height: 8),
            _dialogField(nameCtrls[3], '비고', ''),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
        ],
      ),
    );
    for (final c in nameCtrls) { c.dispose(); }
    if (result != true) return;
    final svc = ServiceInfo(
      serverIp: serverIp,
      name: nameCtrls[0].text.trim(),
      workers: nameCtrls[1].text.trim(),
      gpuUsage: nameCtrls[2].text.trim(),
      note: nameCtrls[3].text.trim(),
    );
    await widget.onSave([...widget.services, svc]);
  }

  Widget _dialogField(TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Future<void> _deleteService(ServiceInfo target) async {
    final updated = widget.services.where((s) => s != target).toList();
    await widget.onSave(updated);
  }

  Future<void> _deleteServer(String ip) async {
    final updated = widget.services.where((s) => s.serverIp.trim() != ip).toList();
    await widget.onSave(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ips = _serverIps();
    final cs = widget.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ips.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.apps_outlined, size: 40,
                        color: cs.onSurface.withValues(alpha: 0.15)),
                    const SizedBox(height: 10),
                    Text('등록된 서버가 없습니다.',
                        style: TextStyle(fontSize: 13,
                            color: cs.onSurface.withValues(alpha: 0.35))),
                  ]),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ips.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _buildServerCard(ips[i], cs),
                ),
        ),
        // 하단 서버 추가 버튼
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(
                color: cs.outlineVariant.withValues(alpha: 0.2))),
          ),
          child: Row(children: [
            InkWell(
              onTap: _addServer,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add, size: 14, color: _color),
                  const SizedBox(width: 4),
                  Text('서버 추가',
                      style: TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w600, color: _color)),
                ]),
              ),
            ),
            const Spacer(),
            Text('서버 ${ips.length}개  서비스 ${widget.services.length}개',
                style: TextStyle(fontSize: 11,
                    color: cs.onSurface.withValues(alpha: 0.35))),
          ]),
        ),
      ],
    );
  }

  Widget _buildServerCard(String ip, ColorScheme cs) {
    final svcs = _servicesFor(ip);
    final serviceNames = svcs.map((s) => s.name).where((n) => n.isNotEmpty).toList();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── 서버 헤더
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _color.withValues(alpha: 0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            border: Border(bottom: BorderSide(
                color: _color.withValues(alpha: 0.15))),
          ),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.computer_outlined, size: 15, color: _color),
            ),
            const SizedBox(width: 10),
            Text(ip.isEmpty ? '(IP 없음)' : ip,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _color,
                    fontFamily: 'monospace')),
            const SizedBox(width: 10),
            // 서비스 이름 칩
            Expanded(
              child: Wrap(spacing: 4, children: serviceNames.map((n) =>
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(n,
                      style: TextStyle(fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _color.withValues(alpha: 0.8))),
                )
              ).toList()),
            ),
            // 서버 삭제
            IconButton(
              onPressed: () => _deleteServer(ip),
              icon: Icon(Icons.delete_outline, size: 15,
                  color: cs.onSurface.withValues(alpha: 0.3)),
              tooltip: '서버 삭제',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
          ]),
        ),

        // ── 컬럼 헤더
        Container(
          color: cs.onSurface.withValues(alpha: 0.025),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            _colHeader('서비스명', 120, cs),
            _colHeader('Workers', 75, cs),
            _colHeader('GPU 사용량', 120, cs),
            _colHeader('비고', 0, cs),
            const SizedBox(width: 32),
          ]),
        ),

        // ── 서비스 행들
        ...svcs.map((svc) => _ServiceRow(
          svc: svc,
          colorScheme: cs,
          accentColor: _color,
          onDelete: () => _deleteService(svc),
          onChanged: (updated) {
            final list = widget.services.toList();
            final idx = list.indexOf(svc);
            if (idx >= 0) list[idx] = updated;
            widget.onSave(list);
          },
        )),

        // ── 서비스 추가 버튼
        InkWell(
          onTap: () => _addService(ip),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.2))),
            ),
            child: Row(children: [
              Icon(Icons.add, size: 13, color: _color.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text('서비스 추가',
                  style: TextStyle(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _color.withValues(alpha: 0.6))),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _colHeader(String label, double width, ColorScheme cs) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: _color.withValues(alpha: 0.6), letterSpacing: 0.3)),
    );
    return width == 0 ? Expanded(child: child) : SizedBox(width: width, child: child);
  }
}

// ── 서비스 인라인 행
class _ServiceRow extends StatefulWidget {
  final ServiceInfo svc;
  final ColorScheme colorScheme;
  final Color accentColor;
  final VoidCallback onDelete;
  final void Function(ServiceInfo) onChanged;

  const _ServiceRow({
    required this.svc,
    required this.colorScheme,
    required this.accentColor,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_ServiceRow> createState() => _ServiceRowState();
}

class _ServiceRowState extends State<_ServiceRow> {
  bool _hovered = false;
  Timer? _saveTimer;
  late TextEditingController _nameCtrl;
  late TextEditingController _workersCtrl;
  late TextEditingController _gpuCtrl;
  late TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.svc.name);
    _workersCtrl = TextEditingController(text: widget.svc.workers);
    _gpuCtrl = TextEditingController(text: widget.svc.gpuUsage);
    _noteCtrl = TextEditingController(text: widget.svc.note);
  }

  @override
  void didUpdateWidget(_ServiceRow old) {
    super.didUpdateWidget(old);
    if (old.svc != widget.svc) {
      _nameCtrl.text = widget.svc.name;
      _workersCtrl.text = widget.svc.workers;
      _gpuCtrl.text = widget.svc.gpuUsage;
      _noteCtrl.text = widget.svc.note;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _nameCtrl.dispose();
    _workersCtrl.dispose();
    _gpuCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), () {
      widget.onChanged(widget.svc.copyWith(
        name: _nameCtrl.text.trim(),
        workers: _workersCtrl.text.trim(),
        gpuUsage: _gpuCtrl.text.trim(),
        note: _noteCtrl.text.trim(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        color: _hovered ? widget.accentColor.withValues(alpha: 0.04) : Colors.transparent,
        child: Row(children: [
          _cell(_nameCtrl, 120, cs),
          _cell(_workersCtrl, 75, cs),
          _cell(_gpuCtrl, 120, cs),
          _cellFlex(_noteCtrl, cs),
          SizedBox(
            width: 32,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: Icon(Icons.delete_outline,
                    color: cs.error.withValues(alpha: 0.6)),
                onPressed: widget.onDelete,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _cell(TextEditingController ctrl, double width, ColorScheme cs) {
    return SizedBox(
      width: width,
      child: _buildTextField(ctrl, cs),
    );
  }

  Widget _cellFlex(TextEditingController ctrl, ColorScheme cs) {
    return Expanded(child: _buildTextField(ctrl, cs));
  }

  Widget _buildTextField(TextEditingController ctrl, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: TextField(
        controller: ctrl,
        onChanged: (_) => _scheduleSave(),
        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
        decoration: InputDecoration(
          hintText: ctrl.text.isEmpty ? '—' : null,
          hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.25), fontSize: 12),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        ),
      ),
    );
  }
}
