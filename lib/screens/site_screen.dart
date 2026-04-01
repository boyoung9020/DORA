import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
import '../widgets/glass_container.dart';
import '../utils/avatar_color.dart';
import '../models/site_detail.dart';
import '../services/site_detail_service.dart';

class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  final SiteDetailService _service = SiteDetailService();

  bool _isLoading = false;
  String? _error;
  List<SiteDetail> _sites = [];
  SiteDetail? _selectedSite;
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
    });
  }

  void _startEdit() {
    final site = _selectedSite!;
    _nameCtrl.text = site.name;
    _descCtrl.text = site.description;
    _editServers = site.servers.map((s) => ServerInfo(ip: s.ip, username: s.username, note: s.note)).toList();
    _editDatabases = site.databases.map((d) => DatabaseInfo(name: d.name, type: d.type, note: d.note)).toList();
    _editServices = site.services.map((s) => ServiceInfo(name: s.name, version: s.version, note: s.note)).toList();
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
    final project = projects.where((p) => p.id == site.projectId).firstOrNull;

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
                      if (project != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: project.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(project.name,
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: project.color),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 4),
                      ],
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

          // ── 서버 정보
          _buildSection(
            icon: Icons.computer,
            title: '서버 정보',
            colorScheme: colorScheme,
            isEmpty: site.servers.isEmpty,
            emptyLabel: '등록된 서버 정보가 없습니다.',
            child: Column(
              children: site.servers.map((srv) {
                return _buildInfoCard(
                  colorScheme: colorScheme,
                  rows: [
                    _InfoRow(label: 'IP 주소', value: srv.ip),
                    _InfoRow(label: '사용자', value: srv.username),
                    if (srv.note.isNotEmpty)
                      _InfoRow(label: '메모', value: srv.note),
                  ],
                );
              }).toList(),
            ),
          ),
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
                    if (db.note.isNotEmpty)
                      _InfoRow(label: '메모', value: db.note),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          // ── 서비스
          _buildSection(
            icon: Icons.rocket_launch_outlined,
            title: '배포 서비스',
            colorScheme: colorScheme,
            isEmpty: site.services.isEmpty,
            emptyLabel: '등록된 서비스 정보가 없습니다.',
            child: Column(
              children: site.services.map((svc) {
                return _buildInfoCard(
                  colorScheme: colorScheme,
                  rows: [
                    _InfoRow(label: '서비스명', value: svc.name),
                    _InfoRow(label: '버전', value: svc.version),
                    if (svc.note.isNotEmpty)
                      _InfoRow(label: '메모', value: svc.note),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
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
        children: rows
            .map((r) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(r.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.5))),
                      ),
                      Expanded(
                        child: Text(
                          r.value.isNotEmpty ? r.value : '—',
                          style: TextStyle(
                              fontSize: 13,
                              color: r.value.isNotEmpty
                                  ? colorScheme.onSurface
                                  : colorScheme.onSurface
                                      .withValues(alpha: 0.3)),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
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

          // 서버 정보
          _editSectionTitle(Icons.computer, '서버 정보', colorScheme),
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
                    hint: '예) 192.168.1.1',
                    onChanged: (v) =>
                        setState(() => _editServers[i] = srv.copyWith(ip: v))),
                _EditField(
                    label: '사용자명',
                    value: srv.username,
                    hint: '예) ubuntu',
                    onChanged: (v) => setState(
                        () => _editServers[i] = srv.copyWith(username: v))),
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
            label: '서버 추가',
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
                    hint: '예) PostgreSQL 15',
                    onChanged: (v) => setState(
                        () => _editDatabases[i] = db.copyWith(type: v))),
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

          // 배포 서비스
          _editSectionTitle(
              Icons.rocket_launch_outlined, '배포 서비스', colorScheme),
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
                    hint: '예) Nginx',
                    onChanged: (v) => setState(
                        () => _editServices[i] = svc.copyWith(name: v))),
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
  const _InfoRow({required this.label, required this.value});
}

class _EditField {
  final String label;
  final String value;
  final String hint;
  final void Function(String) onChanged;
  const _EditField({
    required this.label,
    required this.value,
    required this.hint,
    required this.onChanged,
  });
}
