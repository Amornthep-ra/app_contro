import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

const int controlPresetSlotCount = 5;

class ControlPresetSlot {
  const ControlPresetSlot({
    required this.slot,
    required this.name,
    required this.hasData,
  });

  final int slot;
  final String name;
  final bool hasData;
}

typedef ControlPresetSave =
    FutureOr<ControlPresetSlot?> Function(ControlPresetSlot slot);
typedef ControlPresetLoad = FutureOr<void> Function(ControlPresetSlot slot);
typedef ControlPresetClear =
    FutureOr<ControlPresetSlot> Function(ControlPresetSlot slot);

Future<void> showControlPresetDialog({
  required BuildContext context,
  required bool isThai,
  required List<ControlPresetSlot> slots,
  required ControlPresetSave onSave,
  required ControlPresetLoad onLoad,
  required ControlPresetClear onClear,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: isThai ? 'Close preset dialog' : 'Close preset dialog',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    // showGeneralDialog has no Material, so text would fall back to the
    // framework's monospace error style; this gives it the app's theme font.
    pageBuilder: (context, _, __) => Material(
      type: MaterialType.transparency,
      child: _ControlPresetDialog(
        isThai: isThai,
        slots: slots,
        onSave: onSave,
        onLoad: onLoad,
        onClear: onClear,
      ),
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

class _ControlPresetDialog extends StatefulWidget {
  const _ControlPresetDialog({
    required this.isThai,
    required this.slots,
    required this.onSave,
    required this.onLoad,
    required this.onClear,
  });

  final bool isThai;
  final List<ControlPresetSlot> slots;
  final ControlPresetSave onSave;
  final ControlPresetLoad onLoad;
  final ControlPresetClear onClear;

  @override
  State<_ControlPresetDialog> createState() => _ControlPresetDialogState();
}

class _ControlPresetDialogState extends State<_ControlPresetDialog> {
  late Map<int, ControlPresetSlot> _slots;
  final Set<int> _busySlots = <int>{};

  @override
  void initState() {
    super.initState();
    _slots = {for (final slot in widget.slots) slot.slot: slot};
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: ColoredBox(color: const Color(0xFF35206B).withAlpha(42)),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A 600px-tall landscape viewport loses enough height to the
              // system insets that it needs the condensed three-slot layout.
              final compact = constraints.maxHeight < 600;
              final modalHeight = math
                  .min(compact ? 340.0 : 560.0, constraints.maxHeight - 16)
                  .toDouble();
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SizedBox(
                      height: modalHeight,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(compact ? 24 : 28),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.white.withAlpha(208),
                                  const Color(0xFFF8EEFF).withAlpha(186),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                compact ? 24 : 28,
                              ),
                              border: Border.all(
                                color: Colors.white.withAlpha(238),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE9B8FF).withAlpha(145),
                                  blurRadius: 32,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 10 : 20,
                                compact ? 8 : 18,
                                compact ? 10 : 20,
                                compact ? 8 : 18,
                              ),
                              child: Column(
                                children: [
                                  _DialogHeader(
                                    isThai: widget.isThai,
                                    compact: compact,
                                  ),
                                  SizedBox(height: compact ? 4 : 14),
                                  Expanded(
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: _slots.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: compact ? 4 : 10),
                                      itemBuilder: (context, index) {
                                        final slot =
                                            _slots[widget.slots[index].slot];
                                        if (slot == null) {
                                          return const SizedBox.shrink();
                                        }
                                        return _PresetSlotCard(
                                          slot: slot,
                                          isThai: widget.isThai,
                                          compact: compact,
                                          busy: _busySlots.contains(slot.slot),
                                          onSave: () => _save(slot),
                                          onLoad: () => _load(slot),
                                          onClear: () => _clear(slot),
                                        );
                                      },
                                    ),
                                  ),
                                  SizedBox(height: compact ? 6 : 14),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: _CloseButton(
                                      compact: compact,
                                      label: widget.isThai ? 'Close' : 'Close',
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _save(ControlPresetSlot slot) async {
    if (_busySlots.contains(slot.slot)) return;
    setState(() => _busySlots.add(slot.slot));
    try {
      final updated = await widget.onSave(slot);
      if (updated != null && mounted) {
        setState(() => _slots[slot.slot] = updated);
      }
    } finally {
      if (mounted) setState(() => _busySlots.remove(slot.slot));
    }
  }

  Future<void> _load(ControlPresetSlot slot) async {
    if (_busySlots.contains(slot.slot)) return;
    setState(() => _busySlots.add(slot.slot));
    try {
      await widget.onLoad(slot);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busySlots.remove(slot.slot));
    }
  }

  Future<void> _clear(ControlPresetSlot slot) async {
    if (_busySlots.contains(slot.slot)) return;
    setState(() => _busySlots.add(slot.slot));
    try {
      final updated = await widget.onClear(slot);
      if (mounted) setState(() => _slots[slot.slot] = updated);
    } finally {
      if (mounted) setState(() => _busySlots.remove(slot.slot));
    }
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.isThai, required this.compact});

  final bool isThai;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 36 : 58,
          height: compact ? 36 : 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF4E7FF).withAlpha(220),
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC084FC).withAlpha(112),
                blurRadius: 14,
              ),
            ],
          ),
          child: Icon(
            Icons.bookmark_rounded,
            color: Color(0xFFF4B62D),
            size: compact ? 21 : 31,
          ),
        ),
        SizedBox(width: compact ? 8 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isThai ? 'Presets' : 'Presets',
                style: TextStyle(
                  color: Color(0xFF3D217A),
                  fontSize: compact ? 19 : 26,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.none,
                ),
              ),
              SizedBox(height: compact ? 0 : 2),
              Text(
                isThai
                    ? 'Save and load layouts with speed settings.'
                    : 'Save and load layouts with speed settings.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF7655B7),
                  fontSize: compact ? 10 : 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetSlotCard extends StatelessWidget {
  const _PresetSlotCard({
    required this.slot,
    required this.isThai,
    required this.compact,
    required this.busy,
    required this.onSave,
    required this.onLoad,
    required this.onClear,
  });

  final ControlPresetSlot slot;
  final bool isThai;
  final bool compact;
  final bool busy;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final saved = slot.hasData;
    // Room for the theme font (Roboto) name line above the action row.
    final cardHeight = compact ? 56.0 : null;
    return Container(
      height: cardHeight,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 14,
        vertical: compact ? 5 : 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withAlpha(158),
            const Color(0xFFF4E8FF).withAlpha(126),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(230)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 30 : 42,
            height: compact ? 30 : 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE9B5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF4B62D).withAlpha(74),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Text(
              '${slot.slot}',
              style: TextStyle(
                color: Color(0xFFDD8A00),
                fontSize: compact ? 14 : 20,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.none,
              ),
            ),
          ),
          SizedBox(width: compact ? 7 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slot.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF3D217A),
                    fontSize: compact ? 14 : 19,
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.none,
                  ),
                ),
                SizedBox(height: compact ? 1 : 8),
                Wrap(
                  spacing: compact ? 4 : 7,
                  runSpacing: compact ? 3 : 6,
                  children: [
                    if (saved)
                      _PresetActionButton(
                        label: isThai ? 'Load' : 'Load',
                        icon: Icons.download_rounded,
                        color: const Color(0xFF22A85A),
                        compact: compact,
                        onPressed: busy ? null : onLoad,
                      ),
                    _PresetActionButton(
                      label: saved ? 'Replace' : 'Save',
                      icon: Icons.save_rounded,
                      color: const Color(0xFF9B5DE5),
                      compact: compact,
                      onPressed: busy ? null : onSave,
                    ),
                    if (saved)
                      _PresetActionButton(
                        label: isThai ? 'Clear' : 'Clear',
                        icon: Icons.delete_outline_rounded,
                        color: const Color(0xFFE85D75),
                        compact: compact,
                        onPressed: busy ? null : onClear,
                      ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 4 : 10),
          SizedBox(
            width: compact ? 48 : 62,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusBadge(saved: saved, isThai: isThai, compact: compact),
                if (busy) ...[
                  const SizedBox(height: 8),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.saved,
    required this.isThai,
    required this.compact,
  });

  final bool saved;
  final bool isThai;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = saved ? const Color(0xFF22A85A) : const Color(0xFF8D74C6);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 9,
        vertical: compact ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withAlpha(82)),
      ),
      child: Text(
        saved ? (isThai ? 'Saved' : 'Saved') : (isThai ? 'Empty' : 'Empty'),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontSize: compact ? 8 : 11,
          fontWeight: FontWeight.w800,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}

class _PresetActionButton extends StatelessWidget {
  const _PresetActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final style = TextButton.styleFrom(
      foregroundColor: color,
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      minimumSize: compact ? const Size(24, 22) : const Size(44, 38),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(decoration: TextDecoration.none),
    );
    final button = compact
        ? TextButton(
            onPressed: onPressed,
            style: style,
            child: Icon(icon, size: 13, semanticLabel: label),
          )
        : TextButton.icon(
            onPressed: onPressed,
            icon: Icon(icon, size: 16),
            label: Text(label),
            style: style,
          );
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withAlpha(35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withAlpha(125)),
            boxShadow: [BoxShadow(color: color.withAlpha(70), blurRadius: 9)],
          ),
          child: button,
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.label,
    required this.onPressed,
    required this.compact,
  });

  final String label;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF57349B),
        minimumSize: Size(compact ? 88 : 116, compact ? 30 : 46),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 11 : 18,
          vertical: compact ? 3 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: Color(0xFFCFA8FA), width: 1.5),
        ),
        backgroundColor: Colors.white.withAlpha(140),
        textStyle: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(decoration: TextDecoration.none),
      ),
    );
  }
}
