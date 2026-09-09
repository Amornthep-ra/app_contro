import 'dart:ui';

import 'package:flutter/material.dart';

/// Shared Cat Light surface for controller dialogs and modal sheets.
class CatGlassModalSurface extends StatelessWidget {
  const CatGlassModalSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withAlpha(225),
                const Color(0xFFF8EEFF).withAlpha(205),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withAlpha(238), width: 1.35),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB889E5).withAlpha(82),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

Future<String?> showCatPresetNameDialog({
  required BuildContext context,
  required bool isThai,
  required String? Function(String value) validator,
  String? currentName,
}) async {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: isThai
        ? 'Close rename preset dialog'
        : 'Close rename preset dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) => _CatPresetNameDialog(
      isThai: isThai,
      currentName: currentName,
      validator: validator,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: .97, end: 1).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    ),
  );
}

class _CatPresetNameDialog extends StatefulWidget {
  const _CatPresetNameDialog({
    required this.isThai,
    required this.currentName,
    required this.validator,
  });

  final bool isThai;
  final String? currentName;
  final String? Function(String value) validator;

  @override
  State<_CatPresetNameDialog> createState() => _CatPresetNameDialogState();
}

class _CatPresetNameDialogState extends State<_CatPresetNameDialog> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  String? _errorText;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
    _focusNode = FocusNode();
    _errorText = widget.validator(_controller.text);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_closing) return;
    final value = _controller.text.trim();
    final validation = widget.validator(value);
    if (validation != null) {
      setState(() => _errorText = validation);
      return;
    }
    setState(() => _closing = true);
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isThai ? 'Rename Preset' : 'Rename Preset';
    final hint = widget.isThai ? 'Preset name' : 'Preset name';
    final helper = widget.isThai
        ? 'Letters, numbers, spaces, - and _ only'
        : 'Letters, numbers, spaces, - and _ only';
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ColoredBox(color: const Color(0xFF35206B).withAlpha(42)),
        ),
        SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: CatGlassModalSurface(
                  borderRadius: 24,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Material(
                    color: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF261B39),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          autofocus: true,
                          maxLength: 24,
                          style: const TextStyle(
                            color: Color(0xFF261B39),
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: hint,
                            helperText: helper,
                            errorText: _errorText,
                            filled: true,
                            fillColor: Colors.white.withAlpha(174),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFC7B7E8),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFC7B7E8),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFF37D8FF),
                                width: 1.6,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (!_closing) {
                              setState(
                                () => _errorText = widget.validator(value),
                              );
                            }
                          },
                          onSubmitted: (_) => _submit(),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: _closing
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: Text(widget.isThai ? 'Cancel' : 'Cancel'),
                            ),
                            const SizedBox(width: 8),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF7256B6),
                                    Color(0xFF37D8FF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _errorText != null || _closing
                                    ? null
                                    : _submit,
                                child: Text(widget.isThai ? 'Save' : 'Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
