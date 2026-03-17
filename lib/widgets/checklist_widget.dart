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

  const ChecklistWidget({
    super.key,
    required this.checklist,
    required this.members,
    required this.onItemToggled,
    required this.onItemDeleted,
    required this.onItemAdded,
    required this.onChecklistDeleted,
    required this.onItemUpdated,
  });

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isAddingItem = false;
  final TextEditingController _newItemController = TextEditingController();
  final FocusNode _newItemFocusNode = FocusNode();

  @override
  void dispose() {
    _newItemController.dispose();
    _newItemFocusNode.dispose();
    super.dispose();
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
    // 항목 추가 후 계속 입력할 수 있도록 포커스 유지
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newItemFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final checklist = widget.checklist;
    final progressPercent = (checklist.progress * 100).round();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.brightness == Brightness.dark
            ? const Color(0xFF161B2E)
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 체크박스 아이콘 + 제목 + Delete 버튼
          Row(
            children: [
              Icon(
                Icons.check_box_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  checklist.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => widget.onChecklistDeleted(checklist.id),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: colorScheme.error,
                ),
                child: const Text('Delete', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 진행률 바
          Row(
            children: [
              Text(
                '$progressPercent%',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: checklist.progress,
                    minHeight: 6,
                    backgroundColor: colorScheme.outline.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progressPercent == 100
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 항목 목록
          ...checklist.items.map(
            (item) => _ChecklistItemRow(
              key: ValueKey(item.id),
              item: item,
              members: widget.members,
              onToggled: (checked) => widget.onItemToggled(item.id, checked),
              onDeleted: () => widget.onItemDeleted(item.id),
              onUpdated: (assigneeId, dueDate) =>
                  widget.onItemUpdated(item.id, assigneeId: assigneeId, dueDate: dueDate),
            ),
          ),
          const SizedBox(height: 8),
          // 항목 추가 영역
          if (_isAddingItem) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 24), // 체크박스 공간
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
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
                        border: Border.all(color: colorScheme.primary),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TextField(
                        controller: _newItemController,
                        focusNode: _newItemFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Add an item',
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: InputBorder.none,
                        ),
                        style: TextStyle(fontSize: 14, color: colorScheme.onSurface),
                        onSubmitted: (_) => _submitNewItem(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const SizedBox(width: 32), // 입력창과 버튼 정렬
                ElevatedButton(
                  onPressed: _submitNewItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add', style: TextStyle(fontSize: 13)),
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
                    'Cancel',
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            InkWell(
              onTap: _startAddingItem,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.7)),
                    const SizedBox(width: 4),
                    Text(
                      'Add an item',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final item = widget.item;

    // Hover 시에만 액션을 "보이게" 하되, 레이아웃 크기는 항상 동일하게 유지한다.
    // (hover로 trailing 위젯이 추가/제거되면 텍스트 줄바꿈이 변하며 높이가 흔들릴 수 있음)
    final bool hasAssigneeAction = widget.members.isNotEmpty;
    const double _actionBtnSize = 28;
    const double _actionAreaGap = 0; // IconButton 자체 padding=0이라 별도 gap은 두지 않음
    final int actionCount = hasAssigneeAction ? 3 : 2; // assign + due + delete, or due + delete
    final double trailingWidth =
        (actionCount * _actionBtnSize) + ((actionCount - 1) * _actionAreaGap);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _isHovering
              ? colorScheme.onSurface.withValues(alpha: 0.06)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: item.isChecked,
                onChanged: (v) => widget.onToggled(v ?? false),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.content,
                style: TextStyle(
                  fontSize: 14,
                  color: item.isChecked
                      ? colorScheme.onSurface.withValues(alpha: 0.4)
                      : colorScheme.onSurface,
                  decoration: item.isChecked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            SizedBox(
              width: trailingWidth,
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  // 비-hover 상태에서 보여줄 "요약"(기한만)
                  IgnorePointer(
                    ignoring: true,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: _isHovering ? 0.0 : 1.0,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: item.dueDate == null
                            ? const SizedBox.shrink()
                            : Text(
                                '${item.dueDate!.month}/${item.dueDate!.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                      ),
                    ),
                  ),
                  // hover 상태에서 보여줄 액션 버튼들 (레이아웃은 항상 유지)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IgnorePointer(
                      ignoring: !_isHovering,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: _isHovering ? 1.0 : 0.0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (hasAssigneeAction)
                              IconButton(
                                icon: Icon(
                                  Icons.person_add_outlined,
                                  size: 16,
                                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                                onPressed: () => _showAssignDialog(context),
                                tooltip: 'Assign',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: _actionBtnSize,
                                  minHeight: _actionBtnSize,
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                Icons.schedule_outlined,
                                size: 16,
                                color: colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                              onPressed: () => _showDueDatePicker(context),
                              tooltip: 'Due date',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: _actionBtnSize,
                                minHeight: _actionBtnSize,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: colorScheme.error.withValues(alpha: 0.8),
                              ),
                              onPressed: widget.onDeleted,
                              tooltip: '삭제',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: _actionBtnSize,
                                minHeight: _actionBtnSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
