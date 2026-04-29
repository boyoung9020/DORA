import 'package:flutter/material.dart';

/// 단일 텍스트 입력 다이얼로그.
///
/// 좌측 프로젝트 드롭다운과 동일한 미니멀 톤(elevation 8, 12px radius,
/// outlineVariant 디바이더, primary tint 액션) 으로 구성.
///
/// 반환값: trim 된 입력 문자열, 취소/외부탭/ESC 시 null.
Future<String?> showCleanInputDialog({
  required BuildContext context,
  required String title,
  String? hint,
  String? initial,
  String? helperText,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
}) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => _CleanInputDialog(
      title: title,
      hint: hint,
      initial: initial,
      helperText: helperText,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

/// 단순 확인 다이얼로그.
///
/// 반환값: 확정 시 true, 취소/외부탭/ESC 시 false.
/// [isDestructive] 가 true 면 확정 버튼 색을 `cs.error` 로.
Future<bool> showCleanConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool isDestructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _CleanConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
    ),
  );
  return result ?? false;
}

class _CleanInputDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final String? initial;
  final String? helperText;
  final String confirmLabel;
  final String cancelLabel;

  const _CleanInputDialog({
    required this.title,
    required this.confirmLabel,
    required this.cancelLabel,
    this.hint,
    this.initial,
    this.helperText,
  });

  @override
  State<_CleanInputDialog> createState() => _CleanInputDialogState();
}

class _CleanInputDialogState extends State<_CleanInputDialog> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _CleanDialogShell(
      title: widget.title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.helperText != null) ...[
            Text(
              widget.helperText!,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 6),
          ],
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: TextStyle(fontSize: 14, color: cs.onSurface),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cs.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _CleanDialogActions(
            cancelLabel: widget.cancelLabel,
            confirmLabel: widget.confirmLabel,
            confirmEnabled: _hasText,
            onCancel: () => Navigator.of(context).pop(),
            onConfirm: _submit,
          ),
        ],
      ),
    );
  }
}

class _CleanConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;

  const _CleanConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.isDestructive,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _CleanDialogShell(
      title: title,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: cs.onSurface.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          _CleanDialogActions(
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            confirmEnabled: true,
            confirmColor: isDestructive ? cs.error : cs.primary,
            onCancel: () => Navigator.of(context).pop(false),
            onConfirm: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

/// 공통 다이얼로그 셸: surface + elevation 8 + 12px radius + 타이틀/디바이더/슬롯.
class _CleanDialogShell extends StatelessWidget {
  final String title;
  final Widget child;

  const _CleanDialogShell({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: cs.surface,
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CleanDialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final bool confirmEnabled;
  final Color? confirmColor;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _CleanDialogActions({
    required this.cancelLabel,
    required this.confirmLabel,
    required this.confirmEnabled,
    required this.onCancel,
    required this.onConfirm,
    this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final confirmTint = confirmColor ?? cs.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: cs.onSurface.withValues(alpha: 0.6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(cancelLabel, style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 4),
        TextButton(
          onPressed: confirmEnabled ? onConfirm : null,
          style: TextButton.styleFrom(
            foregroundColor: confirmTint,
            disabledForegroundColor: cs.onSurface.withValues(alpha: 0.3),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
