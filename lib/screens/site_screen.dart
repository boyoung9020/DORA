import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/patch.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../widgets/glass_container.dart';
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
  List<Patch> _sitePatch = [];
  bool _patchesLoading = false;
  // 사이트 추가 시 선택된 프로젝트 ID
  String? _addProjectId;

  // 편집 상태
  bool _isEditing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  List<ServerInfo> _editServers = [];
  List<DatabaseInfo> _editDatabases = [];
  List<ServiceInfo> _editServices = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSites());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.listSites();
      if (!mounted) return;
      setState(() => _sites = data);
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
      _isEditing = false;
      _sitePatch = [];
    });
    _loadSitePatches(site.name);
  }

  Future<void> _loadSitePatches(String siteName) async {
    setState(() => _patchesLoading = true);
    try {
      final patches = await _patchService.getPatchesBySite(siteName: siteName);
      if (mounted) setState(() => _sitePatch = patches);
    } catch (_) {}
    if (mounted) setState(() => _patchesLoading = false);
  }

  void _startEdit() {
    final site = _selectedSite!;
    _nameCtrl.text = site.name;
    _descCtrl.text = site.description;
    _editServers = site.servers.map((s) => ServerInfo(ip: s.ip, username: s.username, password: s.password, gpu: s.gpu, mount: s.mount, note: s.note)).toList();
    _editDatabases = site.databases.map((d) => DatabaseInfo(name: d.name, type: d.type, user: d.user, password: d.password, ip: d.ip, port: d.port, note: d.note)).toList();
    _editServices = site.services
        .map((s) => ServiceInfo(
              name: s.name,
              version: s.version,
              serverIp: s.serverIp,
              workers: s.workers,
              gpuUsage: s.gpuUsage,
              note: s.note,
            ))
        .toList();
    setState(() => _isEditing = true);
  }

  Future<void> _saveEdit() async {
    final site = _selectedSite;
    if (site == null) return;
    setState(() => _isLoading = true);
    try {
      final updated = await _service.updateSite(
        siteId: site.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        servers: _editServers,
        databases: _editDatabases,
        services: _editServices,
      );
      if (!mounted) return;
      setState(() {
        final idx = _sites.indexWhere((s) => s.id == updated.id);
        if (idx >= 0) _sites[idx] = updated;
        _selectedSite = updated;
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSite(SiteDetail site) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('사이트 삭제'),
        content: Text('\'${site.name}\' 사이트를 삭제하시겠습니까?'),
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
        if (_selectedSite?.id == site.id) _selectedSite = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddSiteDialog(ColorScheme colorScheme) {
    final projects = context.read<ProjectProvider>().projects;
    if (projects.isEmpty) return;
    String? selectedProjectId = _addProjectId ?? projects.first.id;
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
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
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('새 사이트 추가',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface)),
                  const SizedBox(height: 16),
                  Text('프로젝트',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.6))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedProjectId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: projects
                        .map((p) => DropdownMenuItem(
                            value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      setDlgState(() => selectedProjectId = v);
                      setState(() => _addProjectId = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: '사이트명 (고객사명)',
                      hintText: '예) 홍길동 회사',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) async {
                      if (selectedProjectId == null) return;
                      await _doCreateSite(selectedProjectId!, ctrl.text.trim());
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          child: const Text('취소')),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          if (selectedProjectId == null) return;
                          await _doCreateSite(
                              selectedProjectId!, ctrl.text.trim());
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        },
                        child: const Text('추가'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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
        _isEditing = false;
        _addProjectId = projectId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // ─── 왼쪽: 사이트 목록
        SizedBox(
          width: 260,
          child: _buildSiteList(colorScheme),
        ),
        VerticalDivider(
            width: 1, color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        // ─── 오른쪽: 사이트 상세
        Expanded(
          child: _selectedSite == null
              ? _buildEmptyDetail(colorScheme)
              : _isEditing
                  ? _buildEditPanel(colorScheme)
                  : _buildDetailPanel(_selectedSite!, colorScheme),
        ),
      ],
    );
  }

  // ─── 사이트 목록 패널
  Widget _buildSiteList(ColorScheme colorScheme) {
    final projects = context.watch<ProjectProvider>().projects;
    return Column(
      children: [
        // 헤더
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
            ),
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
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colorScheme.primary),
                ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: projects.isEmpty
                    ? null
                    : () => _showAddSiteDialog(colorScheme),
                icon: const Icon(Icons.add, size: 20),
                tooltip: '사이트 추가',
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 14,
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!,
                style: TextStyle(color: colorScheme.error, fontSize: 12)),
          ),
        // 목록
        Expanded(
          child: _sites.isEmpty && !_isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.dns_outlined,
                          size: 40,
                          color: colorScheme.onSurface.withValues(alpha: 0.2)),
                      const SizedBox(height: 10),
                      Text('사이트가 없습니다',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.4))),
                      const SizedBox(height: 4),
                      if (projects.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _showAddSiteDialog(colorScheme),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('추가'),
                          style: TextButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _sites.length,
                  itemBuilder: (_, i) =>
                      _buildSiteCard(_sites[i], colorScheme, projects),
                ),
        ),
      ],
    );
  }

  Widget _buildSiteCard(
      SiteDetail site, ColorScheme colorScheme, List<Project> projects) {
    final isSelected = _selectedSite?.id == site.id;
    final chipColor = AvatarColor.getColorForUser(site.name);
    final linkedProjects = projects.where((p) => site.projectIds.contains(p.id)).toList();

    return InkWell(
      onTap: () => _selectSite(site),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.09)
              : null,
          border: Border(
            left: BorderSide(
              color: isSelected ? colorScheme.primary : Colors.transparent,
              width: 3,
            ),
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            // 아바타
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: chipColor),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // 이름 + 요약
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(site.name,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      ...linkedProjects.take(2).map((p) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: p.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(p.name,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: p.color),
                              overflow: TextOverflow.ellipsis),
                        ),
                      )),
                      if (linkedProjects.length > 2)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text('+${linkedProjects.length - 2}',
                              style: TextStyle(
                                  fontSize: 9,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5))),
                        ),
                      _miniChip(
                          '서버 ${site.servers.length}',
                          Icons.computer,
                          colorScheme),
                      const SizedBox(width: 4),
                      _miniChip('DB ${site.databases.length}', Icons.storage,
                          colorScheme),
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

  Widget _miniChip(String label, IconData icon, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 10,
            color: colorScheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: colorScheme.onSurface.withValues(alpha: 0.45))),
      ],
    );
  }

  // ─── 빈 상태
  Widget _buildEmptyDetail(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_outlined,
              size: 56,
              color: colorScheme.onSurface.withValues(alpha: 0.15)),
          const SizedBox(height: 14),
          Text('사이트를 선택하세요',
              style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 4),
          Text('왼쪽 목록에서 사이트를 선택하거나 새로 추가하세요.',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  // ─── 상세 보기 패널
  Widget _buildDetailPanel(SiteDetail site, ColorScheme colorScheme) {
    final chipColor = AvatarColor.getColorForUser(site.name);
    final allProjects = context.watch<ProjectProvider>().projects;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    site.name.isNotEmpty ? site.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: chipColor),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface)),
                    if (site.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(site.description,
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ],
                ),
              ),
              // 액션 버튼
              IconButton(
                onPressed: _startEdit,
                icon: Icon(Icons.edit_outlined,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.5)),
                tooltip: '편집',
              ),
              IconButton(
                onPressed: () => _deleteSite(site),
                icon: Icon(Icons.delete_outline,
                    size: 20, color: colorScheme.error.withValues(alpha: 0.7)),
                tooltip: '삭제',
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── 접속 정보 (ID / PASSWD / GPU / mount — IP 없는 행)
          ..._buildServerAccessSections(site, colorScheme),

          // ── 호스트별 IP가 있는 서버 행(선택)
          ..._buildServerHostSections(site, colorScheme),
          const SizedBox(height: 20),

          // ── 데이터베이스
          _buildSection(
            icon: Icons.storage,
            title: '데이터베이스',
            colorScheme: colorScheme,
            isEmpty: site.databases.isEmpty,
            emptyLabel: '등록된 데이터베이스 정보가 없습니다.',
            child: Column(
              children: site.databases.map((db) {
                return _buildInfoCard(
                  colorScheme: colorScheme,
                  rows: [
                    _InfoRow(label: 'DB명', value: db.name),
                    _InfoRow(label: '종류', value: db.type),
                    if (db.user.isNotEmpty)
                      _InfoRow(label: 'DB 사용자', value: db.user),
                    if (db.password.isNotEmpty)
                      _InfoRow(
                          label: 'DB 비밀번호',
                          value: db.password,
                          isSecret: true),
                    if (db.ip.isNotEmpty)
                      _InfoRow(label: '호스트 IP', value: db.ip),
                    if (db.port.isNotEmpty)
                      _InfoRow(label: '포트', value: db.port),
                    if (db.note.isNotEmpty)
                      _InfoRow(label: '메모', value: db.note),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── 서버별 서비스 (원본 표: server / service / workers / GPU 사용량)
          _buildSection(
            icon: Icons.rocket_launch_outlined,
            title: '서버별 서비스',
            colorScheme: colorScheme,
            isEmpty: site.services.isEmpty,
            emptyLabel: '등록된 서비스(호스트·workers·GPU) 정보가 없습니다.',
            child: Column(
              children: site.services.map((svc) {
                return _buildInfoCard(
                  colorScheme: colorScheme,
                  rows: [
                    _InfoRow(label: '서버(IP)', value: svc.serverIp),
                    _InfoRow(label: '서비스', value: svc.name),
                    _InfoRow(label: 'Workers', value: svc.workers),
                    _InfoRow(label: 'GPU 사용량', value: svc.gpuUsage),
                    if (svc.version.isNotEmpty)
                      _InfoRow(label: '버전', value: svc.version),
                    if (svc.note.isNotEmpty)
                      _InfoRow(label: '메모', value: svc.note),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── 연결된 프로젝트
          _buildConnectedProjects(site, colorScheme, allProjects),
          const SizedBox(height: 20),

          // ── 패치 이력
          _buildPatchHistory(colorScheme, allProjects),
        ],
      ),
    );
  }

  Widget _buildConnectedProjects(SiteDetail site, ColorScheme colorScheme, List<Project> allProjects) {
    final linked = allProjects.where((p) => site.projectIds.contains(p.id)).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder_outlined, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text('연결된 프로젝트',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.85))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${linked.length}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (linked.isEmpty)
          Text('연결된 프로젝트가 없습니다.',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.35)))
        else
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: linked.map((p) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: p.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: p.color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: p.color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: p.color)),
                ],
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildPatchHistory(ColorScheme colorScheme, List<Project> allProjects) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text('패치 이력',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.85))),
            if (_patchesLoading) ...[
              const SizedBox(width: 8),
              SizedBox(width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        if (!_patchesLoading && _sitePatch.isEmpty)
          Text('패치 이력이 없습니다.',
              style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.35)))
        else
          ..._sitePatch.map((patch) {
            final proj = allProjects.where((p) => p.id == patch.projectId).firstOrNull;
            final statusColor = patch.status == 'done'
                ? Colors.green
                : patch.status == 'in_progress'
                    ? Colors.orange
                    : colorScheme.onSurface.withValues(alpha: 0.4);
            final statusLabel = patch.status == 'done'
                ? '완료'
                : patch.status == 'in_progress'
                    ? '진행 중'
                    : '대기';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (proj != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: proj.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(proj.name,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: proj.color)),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (patch.version.isNotEmpty)
                              Text(patch.version,
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface.withValues(alpha: 0.5))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(patch.content,
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(patch.dateDisplay,
                          style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  /// IP 없음 = 접속정보 표(ID / PASSWD / GPU / mount)
  List<Widget> _buildServerAccessSections(
      SiteDetail site, ColorScheme colorScheme) {
    final access =
        site.servers.where((s) => s.ip.trim().isEmpty).toList();
    return [
      _buildSection(
        icon: Icons.badge_outlined,
        title: '접속 정보',
        colorScheme: colorScheme,
        isEmpty: access.isEmpty,
        emptyLabel: '등록된 접속 정보(ID·PASSWD·GPU·mount)가 없습니다.',
        child: Column(
          children: access.map((srv) {
            return _buildInfoCard(
              colorScheme: colorScheme,
              rows: [
                _InfoRow(label: 'ID', value: srv.username),
                if (srv.password.isNotEmpty)
                  _InfoRow(
                      label: 'PASSWD',
                      value: srv.password,
                      isSecret: true)
                else
                  const _InfoRow(label: 'PASSWD', value: ''),
                _InfoRow(label: 'GPU', value: srv.gpu),
                _InfoRow(label: 'mount', value: srv.mount),
                if (srv.note.isNotEmpty)
                  _InfoRow(label: '메모', value: srv.note),
              ],
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  /// IP 있음 = 개별 호스트 행(선택)
  List<Widget> _buildServerHostSections(
      SiteDetail site, ColorScheme colorScheme) {
    final hosts =
        site.servers.where((s) => s.ip.trim().isNotEmpty).toList();
    if (hosts.isEmpty) return [];
    return [
      _buildSection(
        icon: Icons.dns_outlined,
        title: '서버 호스트',
        colorScheme: colorScheme,
        isEmpty: false,
        emptyLabel: '',
        child: Column(
          children: hosts.map((srv) {
            return _buildInfoCard(
              colorScheme: colorScheme,
              rows: [
                _InfoRow(label: 'IP 주소', value: srv.ip),
                if (srv.username.isNotEmpty)
                  _InfoRow(label: 'ID', value: srv.username),
                if (srv.password.isNotEmpty)
                  _InfoRow(
                      label: 'PASSWD', value: srv.password, isSecret: true),
                if (srv.gpu.isNotEmpty)
                  _InfoRow(label: 'GPU', value: srv.gpu),
                if (srv.mount.isNotEmpty)
                  _InfoRow(label: 'mount', value: srv.mount),
                if (srv.note.isNotEmpty)
                  _InfoRow(label: '메모', value: srv.note),
              ],
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 20),
    ];
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
    required bool isEmpty,
    required String emptyLabel,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface.withValues(alpha: 0.85))),
          ],
        ),
        const SizedBox(height: 10),
        if (isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(emptyLabel,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.35))),
          )
        else
          child,
      ],
    );
  }

  Widget _buildInfoCard({
    required ColorScheme colorScheme,
    required List<_InfoRow> rows,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: rows.map((r) => _buildDetailInfoRow(colorScheme, r))            .toList(),
      ),
    );
  }

  Widget _buildDetailInfoRow(ColorScheme colorScheme, _InfoRow r) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              r.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: r.isSecret && r.value.isNotEmpty
                ? _RevealableSecret(value: r.value, colorScheme: colorScheme)
                : Text(
                    r.value.isNotEmpty ? r.value : '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: r.value.isNotEmpty
                          ? colorScheme.onSurface
                          : colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── 편집 패널
  Widget _buildEditPanel(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text('사이트 편집',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface)),
              const Spacer(),
              TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('취소')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isLoading ? null : _saveEdit,
                child: const Text('저장'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 기본 정보
          _editSectionTitle(Icons.info_outline, '기본 정보', colorScheme),
          const SizedBox(height: 10),
          _editTextField('사이트명', _nameCtrl, '사이트명을 입력하세요'),
          const SizedBox(height: 10),
          _editTextField('설명', _descCtrl, '사이트에 대한 간단한 설명', maxLines: 2),
          const SizedBox(height: 24),

          // 접속정보(IP 비움)·호스트(IP 기입) — 원본 표와 동일하게 저장
          _editSectionTitle(Icons.computer, '접속·호스트 정보', colorScheme),
          const SizedBox(height: 6),
          Text(
            'IP를 비우면 「접속 정보」(ID·PASSWD·GPU·mount) 행으로 쓰입니다. 서버별 서비스는 아래 「배포 서비스」에서 편집합니다.',
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 10),
          ..._editServers.asMap().entries.map((e) {
            final i = e.key;
            final srv = e.value;
            return _buildEditCard(
              colorScheme: colorScheme,
              onDelete: () => setState(() => _editServers.removeAt(i)),
              fields: [
                _EditField(
                    label: 'IP 주소',
                    value: srv.ip,
                    hint: '접속정보만: 비움 / 호스트: 10.158…',
                    onChanged: (v) =>
                        setState(() => _editServers[i] = srv.copyWith(ip: v))),
                _EditField(
                    label: 'ID',
                    value: srv.username,
                    hint: '예) gemisoadmin',
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(username: v))),
                _EditField(
                    label: 'PASSWD',
                    value: srv.password,
                    hint: '암호',
                    obscure: true,
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(password: v))),
                _EditField(
                    label: 'GPU',
                    value: srv.gpu,
                    hint: '예) A6000(50G), 서버 당 2개',
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(gpu: v))),
                _EditField(
                    label: 'mount',
                    value: srv.mount,
                    hint: '예) /mnt/npsmain/root',
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(mount: v))),
                _EditField(
                    label: '메모',
                    value: srv.note,
                    hint: '예) 운영 서버',
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(note: v))),
              ],
            );
          }),
          _addItemButton(
            label: '접속·호스트 행 추가',
            colorScheme: colorScheme,
            onTap: () => setState(() => _editServers.add(ServerInfo())),
          ),
          const SizedBox(height: 24),

          // 데이터베이스
          _editSectionTitle(Icons.storage, '데이터베이스', colorScheme),
          const SizedBox(height: 10),
          ..._editDatabases.asMap().entries.map((e) {
            final i = e.key;
            final db = e.value;
            return _buildEditCard(
              colorScheme: colorScheme,
              onDelete: () => setState(() => _editDatabases.removeAt(i)),
              fields: [
                _EditField(
                    label: 'DB명',
                    value: db.name,
                    hint: '예) sync_db',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(name: v))),
                _EditField(
                    label: '종류',
                    value: db.type,
                    hint: '예) PostgreSQL 15 / Milvus',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(type: v))),
                _EditField(
                    label: 'DB 사용자',
                    value: db.user,
                    hint: 'DB 계정',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(user: v))),
                _EditField(
                    label: 'DB 비밀번호',
                    value: db.password,
                    hint: '암호',
                    obscure: true,
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(password: v))),
                _EditField(
                    label: '호스트 IP',
                    value: db.ip,
                    hint: '예) 10.0.0.1',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(ip: v))),
                _EditField(
                    label: '포트',
                    value: db.port,
                    hint: '예) 19530',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(port: v))),
                _EditField(
                    label: '메모',
                    value: db.note,
                    hint: '추가 정보',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(note: v))),
              ],
            );
          }),
          _addItemButton(
            label: 'DB 추가',
            colorScheme: colorScheme,
            onTap: () =>
                setState(() => _editDatabases.add(DatabaseInfo())),
          ),
          const SizedBox(height: 24),

          // 서버별 서비스 (호스트 / service / workers / GPU)
          _editSectionTitle(
              Icons.rocket_launch_outlined, '서버별 서비스', colorScheme),
          const SizedBox(height: 10),
          ..._editServices.asMap().entries.map((e) {
            final i = e.key;
            final svc = e.value;
            return _buildEditCard(
              colorScheme: colorScheme,
              onDelete: () => setState(() => _editServices.removeAt(i)),
              fields: [
                _EditField(
                    label: '서비스명',
                    value: svc.name,
                    hint: '예) Face / OCR / Scene',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(name: v))),
                _EditField(
                    label: '서버(IP)',
                    value: svc.serverIp,
                    hint: '예) 10.158.108.111',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(serverIp: v))),
                _EditField(
                    label: 'Workers',
                    value: svc.workers,
                    hint: '비움 가능 (예: milvus)',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(workers: v))),
                _EditField(
                    label: 'GPU 사용량',
                    value: svc.gpuUsage,
                    hint: '비움 가능. 예: 33734, 8905 / 42000',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(gpuUsage: v))),
                _EditField(
                    label: '버전',
                    value: svc.version,
                    hint: '예) 1.24.0',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(version: v))),
                _EditField(
                    label: '메모',
                    value: svc.note,
                    hint: '추가 정보',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(note: v))),
              ],
            );
          }),
          _addItemButton(
            label: '서비스 추가',
            colorScheme: colorScheme,
            onTap: () => setState(() => _editServices.add(ServiceInfo())),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _editSectionTitle(
      IconData icon, String title, ColorScheme colorScheme) {
    return Row(
      children: [
        Icon(icon, size: 15, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface.withValues(alpha: 0.8))),
      ],
    );
  }

  Widget _editTextField(String label, TextEditingController ctrl, String hint,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13),
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildEditCard({
    required ColorScheme colorScheme,
    required VoidCallback onDelete,
    required List<_EditField> fields,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: fields
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 68,
                              child: Text(f.label,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.55))),
                            ),
                            Expanded(
                              child: TextFormField(
                                initialValue: f.value,
                                obscureText: f.obscure,
                                decoration: InputDecoration(
                                  hintText: f.hint,
                                  hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.35)),
                                  border: const OutlineInputBorder(),
                                  contentPadding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: f.onChanged,
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.close,
                size: 16,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 28, minHeight: 28),
            splashRadius: 12,
          ),
        ],
      ),
    );
  }

  Widget _addItemButton({
    required String label,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.3),
              style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 15, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── 내부 헬퍼 클래스들

class _InfoRow {
  final String label;
  final String value;
  final bool isSecret;
  const _InfoRow({required this.label, required this.value, this.isSecret = false});
}

class _EditField {
  final String label;
  final String value;
  final String hint;
  final bool obscure;
  final void Function(String) onChanged;
  const _EditField({
    required this.label,
    required this.value,
    required this.hint,
    this.obscure = false,
    required this.onChanged,
  });
}

class _RevealableSecret extends StatefulWidget {
  final String value;
  final ColorScheme colorScheme;

  const _RevealableSecret({
    required this.value,
    required this.colorScheme,
  });

  @override
  State<_RevealableSecret> createState() => _RevealableSecretState();
}

class _RevealableSecretState extends State<_RevealableSecret> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SelectableText(
            _visible ? widget.value : '•' * 12,
            style: TextStyle(
              fontSize: 13,
              color: _visible ? cs.onSurface : cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ),
        IconButton(
          tooltip: _visible ? '숨기기' : '표시',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          icon: Icon(
            _visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: cs.onSurface.withValues(alpha: 0.5),
          ),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      ],
    );
  }
}
