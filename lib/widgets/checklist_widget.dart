import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/checklist.dart';
import '../models/user.dart';

/// 체크리스트 위젯 (Trello 스타일)
class ChecklistWidget extends StatefulWidget {
  final Checklist checklist;
  final List<User> members;
  final void Function(String itemId, bool checked) onItemToggled;
  final void Function(String itemId) onItemDeleted;
  final void Function(String checklistId, String content) onItemAdded;
  final void Function(String checklistId) onChecklistDeleted;
  final void Function(String itemId, {String? assigneeId, DateTime? dueDate}) onItemUpdated;
  final void Function(String checklistId, String newTitle)? onTitleUpdated;

  const ChecklistWidget({
    super.key,
    required this.checklist,
    required this.members,
    required this.onItemToggled,
    required this.onItemDeleted,
    required this.onItemAdded,
    required this.onChecklistDeleted,
    required this.onItemUpdated,
    this.onTitleUpdated,
  });

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isAddingItem = false;
  final TextEditingController _newItemController = TextEditingController();
  final FocusNode _newItemFocusNode = FocusNode();

  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.checklist.title);
  }

  @override
  void didUpdateWidget(ChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.checklist.title != widget.checklist.title && !_isEditingTitle) {
      _titleController.text = widget.checklist.title;
    }
  }

  @override
  void dispose() {
    _newItemController.dispose();
    _newItemFocusNode.dispose();
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _startEditingTitle() {
    setState(() => _isEditingTitle = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });
  }

  void _submitTitle() {
    final newTitle = _titleController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.checklist.title) {
      widget.onTitleUpdated?.call(widget.checklist.id, newTitle);
    } else {
      _titleController.text = widget.checklist.title;
    }
    setState(() => _isEditingTitle = false);
  }

  void _startAddingItem() {
    setState(() => _isAddingItem = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newItemFocusNode.requestFocus();
    });
  }

  void _cancelAddingItem() {
    setState(() {
      _isAddingItem = false;
      _newItemController.clear();
    });
  }

  void _submitNewItem() {
    final content = _newItemController.text.trim();
    if (content.isEmpty) return;
    widget.onItemAdded(widget.checklist.id, content);
    _newItemController.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newItemFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final checklist = widget.checklist;
    final progressPercent = (checklist.progress * 100).round();
    final isDark = colorScheme.brightness == Brightness.dark;
    final progressColor = progressPercent == 100 ? const Color(0xFF22C55E) : colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1F35) : const Color(0xFFFAFAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? colorScheme.primary.withValues(alpha: 0.35)
              : colorScheme.primary.withValues(alpha: 0.30),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.primary.withValues(alpha: 0.08)
                  : colorScheme.primary.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(Icons.check_box_outlined, size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _isEditingTitle
                      ? Focus(
                          onKeyEvent: (node, event) {
                            if (event is KeyDownEvent &&
                                (event.logicalKey == LogicalKeyboardKey.enter ||
                                    event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                              _submitTitle();
                              return KeyEventResult.handled;
                            }
                            if (event is KeyDownEvent &&
                                event.logicalKey == LogicalKeyboardKey.escape) {
                              _titleController.text = widget.checklist.title;
                              setState(() => _isEditingTitle = false);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: colorScheme.primary),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
                              ),
                            ),
                            onSubmitted: (_) => _submitTitle(),
                            onTapOutside: (_) => _submitTitle(),
                          ),
                        )
                      : GestureDetector(
                          onTap: widget.onTitleUpdated != null ? _startEditingTitle : null,
                          child: MouseRegion(
                            cursor: widget.onTitleUpdated != null
                                ? SystemMouseCursors.text
                                : MouseCursor.defer,
                            child: Text(
                              checklist.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ),
                        ),
                ),
                // 완료 배지
                if (progressPercent == 100)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF22C55E),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => widget.onChecklistDeleted(checklist.id),
                  icon: Icon(Icons.delete_outline, size: 16, color: colorScheme.error.withValues(alpha: 0.7)),
                  tooltip: '삭제',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                ),
              ],
            ),
          ),

          // ── 진행률 바 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  child: Text(
                    '$progressPercent%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: progressColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: checklist.progress,
                      minHeight: 7,
                      backgroundColor: colorScheme.outline.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${checklist.items.where((i) => i.isChecked).length}/${checklist.items.length}',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),

          // ── 항목 목록 ──
          if (checklist.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: Column(
                children: checklist.items.map(
                  (item) => _ChecklistItemRow(
                    key: ValueKey(item.id),
                    item: item,
                    members: widget.members,
                    onToggled: (checked) => widget.onItemToggled(item.id, checked),
                    onDeleted: () => widget.onItemDeleted(item.id),
                    onUpdated: (assigneeId, dueDate) =>
                        widget.onItemUpdated(item.id, assigneeId: assigneeId, dueDate: dueDate),
                  ),
                ).toList(),
              ),
            ),

          // ── 항목 추가 영역 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
            child: _isAddingItem
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent &&
                              (event.logicalKey == LogicalKeyboardKey.enter ||
                                  event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                            _submitNewItem();
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            border: Border.all(color: colorScheme.primary, width: 1.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: TextField(
                            controller: _newItemController,
                            focusNode: _newItemFocusNode,
                            decoration: InputDecoration(
                              hintText: '항목 내용을 입력하세요',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurface.withValues(alpha: 0.4),
                                fontSize: 13,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              border: InputBorder.none,
                            ),
                            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
                            onSubmitted: (_) => _submitNewItem(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ElevatedButton(
                            onPressed: _submitNewItem,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.primary,
                              foregroundColor: colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              elevation: 0,
                            ),
                            child: const Text('추가', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _cancelAddingItem,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 13,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : InkWell(
                    onTap: _startAddingItem,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 15, color: colorScheme.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 5),
                          Text(
                            '항목 추가',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.primary.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 체크리스트 항목 행 위젯
class _ChecklistItemRow extends StatefulWidget {
  final ChecklistItem item;
  final List<User> members;
  final void Function(bool checked) onToggled;
  final VoidCallback onDeleted;
  final void Function(String? assigneeId, DateTime? dueDate) onUpdated;

  const _ChecklistItemRow({
    super.key,
    required this.item,
    required this.members,
    required this.onToggled,
    required this.onDeleted,
    required this.onUpdated,
  });

  @override
  State<_ChecklistItemRow> createState() => _ChecklistItemRowState();
}

class _ChecklistItemRowState extends State<_ChecklistItemRow> {
  bool _isHovering = false;

  String? _getAssigneeName() {
    if (widget.item.assigneeId == null) return null;
    try {
      return widget.members.firstWhere((m) => m.id == widget.item.assigneeId).username;
    } catch (_) {
      return null;
    }
  }

  bool _isOverdue() {
    final due = widget.item.dueDate;
    if (due == null || widget.item.isChecked) return false;
    return due.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final isDark = colorScheme.brightness == Brightness.dark;
    final assigneeName = _getAssigneeName();
    final isOverdue = _isOverdue();

    // 완료된 항목 배경색
    final checkedBg = isDark
        ? const Color(0xFF22C55E).withValues(alpha: 0.07)
        : const Color(0xFF22C55E).withValues(alpha: 0.06);

    // 왼쪽 accent 색
    final accentColor = item.isChecked
        ? const Color(0xFF22C55E)
        : colorScheme.primary.withValues(alpha: 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: item.isChecked
              ? checkedBg
              : _isHovering
                  ? colorScheme.onSurface.withValues(alpha: isDark ? 0.06 : 0.04)
                  : colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: item.isChecked
                ? const Color(0xFF22C55E).withValues(alpha: 0.25)
                : _isHovering
                    ? colorScheme.primary.withValues(alpha: 0.3)
                    : colorScheme.outline.withValues(alpha: isDark ? 0.15 : 0.12),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 왼쪽 컬러 accent 바
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 3,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                ),
              ),
              // 체크박스
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: item.isChecked,
                    onChanged: (v) => widget.onToggled(v ?? false),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    activeColor: const Color(0xFF22C55E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
              ),
              // 내용 + 배지들
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        item.content,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: item.isChecked ? FontWeight.w400 : FontWeight.w500,
                          color: item.isChecked
                              ? colorScheme.onSurface.withValues(alpha: 0.38)
                              : colorScheme.onSurface.withValues(alpha: 0.9),
                          decoration: item.isChecked ? TextDecoration.lineThrough : null,
                          decorationColor: colorScheme.onSurface.withValues(alpha: 0.38),
                          height: 1.4,
                        ),
                      ),
                      // 담당자 / 기한 배지 (항상 표시)
                      if (assigneeName != null || item.dueDate != null) ...[
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            if (assigneeName != null) ...[
                              _Badge(
                                icon: Icons.person_outline,
                                label: assigneeName,
                                color: colorScheme.primary,
                                isDark: isDark,
                              ),
                              const SizedBox(width: 5),
                            ],
                            if (item.dueDate != null)
                              _Badge(
                                icon: Icons.schedule_outlined,
                                label: '${item.dueDate!.month}/${item.dueDate!.day}',
                                color: isOverdue ? Colors.red : colorScheme.onSurface.withValues(alpha: 0.55),
                                isDark: isDark,
                                isWarning: isOverdue,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 액션 버튼 (hover 시 표시)
              AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: _isHovering ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !_isHovering,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.members.isNotEmpty)
                          _ActionBtn(
                            icon: Icons.person_add_outlined,
                            tooltip: '담당자 지정',
                            color: colorScheme.primary,
                            onTap: () => _showAssignDialog(context),
                          ),
                        _ActionBtn(
                          icon: Icons.schedule_outlined,
                          tooltip: '기한 설정',
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          onTap: () => _showDueDatePicker(context),
                        ),
                        _ActionBtn(
                          icon: Icons.close,
                          tooltip: '삭제',
                          color: colorScheme.error,
                          onTap: widget.onDeleted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showAssignDialog(BuildContext context) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('담당자 지정'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('지정 해제'),
          ),
          ...widget.members.map(
            (m) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, m.id),
              child: Text(m.username),
            ),
          ),
        ],
      ),
    );
    if (selected != null) {
      widget.onUpdated(selected.isEmpty ? null : selected, widget.item.dueDate);
    }
  }

  Future<void> _showDueDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.item.dueDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      widget.onUpdated(widget.item.assigneeId, picked);
    }
  }
}

/// 작은 배지 위젯
class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final bool isWarning;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    this.isWarning = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(4),
        border: isWarning
            ? Border.all(color: color.withValues(alpha: 0.35), width: 0.8)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 액션 아이콘 버튼
class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}
