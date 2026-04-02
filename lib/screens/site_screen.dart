import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/project_provider.dart';
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
  String? _addProjectId;

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
        }
      });
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSiteTabBar(colorScheme, projects),
        if (_error != null)
          Container(
            color: colorScheme.errorContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(_error!, style: TextStyle(color: colorScheme.onErrorContainer, fontSize: 12)),
          ),
        Expanded(
          child: _isLoading && _sites.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _selectedSite == null
                  ? _buildEmpty(colorScheme, projects)
                  : _buildTableArea(_selectedSite!, colorScheme),
        ),
      ],
    );
  }

  Widget _buildSiteTabBar(ColorScheme colorScheme, List<Project> projects) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.35))),
      ),
      child: Row(children: [
        Expanded(
          child: _sites.isEmpty ? const SizedBox() : ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _sites.length,
            itemBuilder: (_, i) {
              final site = _sites[i];
              final isSelected = _selectedSite?.id == site.id;
              final dotColor = AvatarColor.getColorForUser(site.name);
              return InkWell(
                onTap: () => setState(() => _selectedSite = site),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(
                        color: isSelected ? colorScheme.primary : Colors.transparent, width: 2.5)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 8, height: 8,
                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(site.name, style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface.withValues(alpha: 0.7))),
                  ]),
                ),
              );
            },
          ),
        ),
        Row(children: [
          if (_isLoading)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))),
          if (_selectedSite != null)
            Tooltip(
              message: '사이트 삭제',
              child: IconButton(
                icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.onSurface.withValues(alpha: 0.4)),
                onPressed: () => _deleteSite(_selectedSite!),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              ),
            ),
          Tooltip(
            message: '새 사이트 추가',
            child: IconButton(
              icon: Icon(Icons.add, size: 20, color: colorScheme.primary),
              onPressed: projects.isEmpty ? null : () => _showAddSiteDialog(colorScheme),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
            ),
          ),
          const SizedBox(width: 8),
        ]),
      ]),
    );
  }

  Widget _buildEmpty(ColorScheme colorScheme, List<Project> projects) {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.dns_outlined, size: 48, color: colorScheme.onSurface.withValues(alpha: 0.18)),
      const SizedBox(height: 12),
      Text('사이트가 없습니다', style: TextStyle(fontSize: 14, color: colorScheme.onSurface.withValues(alpha: 0.4))),
      if (projects.isNotEmpty) ...[
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => _showAddSiteDialog(colorScheme),
            icon: const Icon(Icons.add, size: 16), label: const Text('사이트 추가')),
      ],
    ]));
  }

  Widget _buildTableArea(SiteDetail site, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 5, child: _ServerTable(
          key: ValueKey('server_${site.id}'),
          site: site, colorScheme: colorScheme,
          onSave: _saveServers,
        )),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: _DatabaseTable(
          key: ValueKey('db_${site.id}'),
          site: site, colorScheme: colorScheme,
          onSave: _saveDatabases,
        )),
        const SizedBox(width: 12),
        Expanded(flex: 4, child: _ServiceTable(
          key: ValueKey('svc_${site.id}'),
          site: site, colorScheme: colorScheme,
          onSave: _saveServices,
        )),
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
  // 각 행의 각 셀에 대한 컨트롤러 + 신규 행 컨트롤러
  List<List<TextEditingController>> _ctrls = [];
  List<List<TextEditingController>> _newRowCtrls = [];
  bool _addingRow = false;
  Timer? _saveTimer;

  Color get color;
  IconData get icon;
  String get title;
  List<String> get columns;
  List<double> get colWidths; // 0 = flex
  List<bool> get isPassword;

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
    _ctrls[rowIndex].forEach((c) => c.dispose());
    _ctrls.removeAt(rowIndex);
    await onSave(items);
  }

  void _startAddRow() {
    setState(() {
      _newRowCtrls = List.generate(columns.length, (_) => TextEditingController());
      _addingRow = true;
    });
    // 첫 셀에 포커스
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_newRowCtrls.isNotEmpty) FocusScope.of(context).requestFocus(FocusNode());
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
    return Container(
      decoration: BoxDecoration(
        color: widget.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.colorScheme.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // 섹션 헤더
        _buildHeader(),
        // 컬럼 헤더
        _buildColHeader(),
        // 데이터 행
        Expanded(child: _buildBody()),
      ]),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: widget.colorScheme.outlineVariant.withValues(alpha: 0.3))),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Text('${getItems().length}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
        const Spacer(),
        InkWell(
          onTap: _addingRow ? null : _startAddRow,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, size: 14, color: _addingRow ? color.withValues(alpha: 0.3) : color),
              const SizedBox(width: 2),
              Text('행 추가', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: _addingRow ? color.withValues(alpha: 0.3) : color)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildColHeader() {
    return Container(
      color: widget.colorScheme.onSurface.withValues(alpha: 0.03),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(children: [
        ...List.generate(columns.length, (i) {
          final cell = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(columns[i], style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: widget.colorScheme.onSurface.withValues(alpha: 0.5))),
          );
          return colWidths[i] == 0 ? Expanded(child: cell) : SizedBox(width: colWidths[i], child: cell);
        }),
        const SizedBox(width: 30),
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

  Widget _buildDataRow(int rowIndex) {
    if (rowIndex >= _ctrls.length) return const SizedBox.shrink();
    return _InlineRow(
      controllers: _ctrls[rowIndex],
      colWidths: colWidths,
      isPassword: isPassword,
      colorScheme: widget.colorScheme,
      accentColor: color,
      onChange: (_) => _scheduleSave(rowIndex),
      onDelete: () => _deleteRow(rowIndex),
    );
  }

  Widget _buildNewRow() {
    return Container(
      color: color.withValues(alpha: 0.04),
      child: Row(children: [
        ...List.generate(columns.length, (i) {
          final cell = _InlineCell(
            controller: _newRowCtrls[i],
            isPassword: i < isPassword.length && isPassword[i],
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
          width: 30,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              width: 26,
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 14,
                icon: Icon(Icons.check, color: color),
                onPressed: _commitNewRow,
                tooltip: '확인',
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── 인라인 행
class _InlineRow extends StatefulWidget {
  final List<TextEditingController> controllers;
  final List<double> colWidths;
  final List<bool> isPassword;
  final ColorScheme colorScheme;
  final Color accentColor;
  final void Function(String) onChange;
  final Future<void> Function() onDelete;

  const _InlineRow({
    required this.controllers,
    required this.colWidths,
    required this.isPassword,
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
        color: _hovered ? widget.accentColor.withValues(alpha: 0.04) : Colors.transparent,
        child: Row(children: [
          ...List.generate(widget.controllers.length, (i) {
            final cell = _InlineCell(
              controller: widget.controllers[i],
              isPassword: i < widget.isPassword.length && widget.isPassword[i],
              accentColor: widget.accentColor,
              colorScheme: widget.colorScheme,
              onChange: widget.onChange,
            );
            return widget.colWidths[i] == 0
                ? Expanded(child: cell)
                : SizedBox(width: widget.colWidths[i], child: cell);
          }),
          SizedBox(
            width: 30,
            child: AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: SizedBox(
                width: 26,
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  icon: Icon(Icons.delete_outline,
                      color: widget.colorScheme.error.withValues(alpha: 0.6)),
                  onPressed: () async => await widget.onDelete(),
                ),
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
  final bool isPassword;
  final Color accentColor;
  final ColorScheme colorScheme;
  final void Function(String)? onChange;
  final void Function(String)? onSubmitted;
  final bool autofocus;

  const _InlineCell({
    required this.controller,
    required this.isPassword,
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
  bool _obscure = true;

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
              obscureText: widget.isPassword && _obscure,
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
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
              ),
            ),
          ),
          if (widget.isPassword && _focused)
            InkWell(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 12,
                color: widget.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          if (widget.isPassword && !_focused && widget.controller.text.isNotEmpty)
            InkWell(
              onTap: () { setState(() => _obscure = !_obscure); },
              child: Icon(
                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 11,
                color: widget.colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ),
          if (!widget.isPassword && widget.controller.text.isNotEmpty && _focused)
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
  @override List<String> get columns => ['IP', 'ID', '비밀번호', 'GPU', '마운트', '비고'];
  @override List<double> get colWidths => [130, 85, 105, 65, 90, 0];
  @override List<bool> get isPassword => [false, false, true, false, false, false];
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
  @override List<String> get columns => ['DB명', '종류', '계정', '비밀번호', 'IP', '포트', '비고'];
  @override List<double> get colWidths => [80, 75, 75, 100, 110, 55, 0];
  @override List<bool> get isPassword => [false, false, false, true, false, false, false];
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
  @override List<String> get columns => ['서비스명', '버전', '서버 IP', 'Workers', 'GPU', '비고'];
  @override List<double> get colWidths => [90, 65, 110, 65, 55, 0];
  @override List<bool> get isPassword => [false, false, false, false, false, false];
  @override List<ServiceInfo> getItems() => widget.site.services;
  @override List<String> itemToStrings(ServiceInfo i) => [i.name, i.version, i.serverIp, i.workers, i.gpuUsage, i.note];
  @override ServiceInfo stringsToItem(List<String> v) =>
      ServiceInfo(name: v[0], version: v[1], serverIp: v[2], workers: v[3], gpuUsage: v[4], note: v[5]);
  @override Future<void> Function(List<ServiceInfo>) get onSave => widget.onSave;
}
