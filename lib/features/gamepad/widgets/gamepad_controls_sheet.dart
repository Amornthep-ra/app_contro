// lib/features/gamepad/widgets/gamepad_controls_sheet.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/ui/lavender_glass.dart';
import '../../../core/widgets/cat_glass_popup.dart';

/// One control the layout editor can show or hide on the pad.
class GamepadControlChoice {
  const GamepadControlChoice({
    required this.id,
    required this.label,
    this.asset,
    this.icon,
  }) : assert(asset != null || icon != null);

  final String id;
  final String label;

  /// Button artwork, when the control has one.
  final String? asset;

  /// Used when there is no artwork (joysticks).
  final IconData? icon;
}

/// A titled group of controls, e.g. "Left pad" or "Joysticks".
class GamepadControlGroup {
  const GamepadControlGroup({required this.title, required this.choices});

  final String title;
  final List<GamepadControlChoice> choices;
}

/// Opens the layout editor's "Buttons" sheet, shared by 4 BTN, 8 BTN and
/// Joystick: tick a control to put it on the pad, untick to remove it.
///
/// Changes apply at once ([onToggle]); Undo in the editor brings them back.
/// "Done" or a tap outside closes the sheet.
Future<void> showGamepadControlsSheet({
  required BuildContext context,
  required List<GamepadControlGroup> groups,
  required bool Function(String id) isActive,
  required void Function(String id) onToggle,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: LavenderPalette.ink.withValues(alpha: 0.28),
    builder: (context) => GamepadControlsSheet(
      groups: groups,
      isActive: isActive,
      onToggle: onToggle,
    ),
  );
}

class GamepadControlsSheet extends StatefulWidget {
  const GamepadControlsSheet({
    super.key,
    required this.groups,
    required this.isActive,
    required this.onToggle,
  });

  final List<GamepadControlGroup> groups;
  final bool Function(String id) isActive;
  final void Function(String id) onToggle;

  @override
  State<GamepadControlsSheet> createState() => _GamepadControlsSheetState();
}

class _GamepadControlsSheetState extends State<GamepadControlsSheet> {
  void _toggle(String id) {
    widget.onToggle(id);
    // The page owns the state; repaint the ticks from it.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    // Same rule as the BLE status sheet: header and Done stay put, only the
    // list scrolls, and the sheet never runs off a short landscape screen.
    final maxHeight = math.max(
      0.0,
      math.min(
        media.size.height * (landscape ? 0.85 : 0.6),
        media.size.height - media.padding.vertical - 48,
      ),
    );

    final header = Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Buttons',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: LavenderPalette.displayFont,
                  fontSize: 18,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: LavenderPalette.ink,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Tap to show or hide a control. Undo brings it back.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: LavenderPalette.inkSoft,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GlassActionButton(
          label: 'Done',
          icon: Icons.check_rounded,
          height: 48,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );

    final body = LayoutBuilder(
      builder: (context, constraints) {
        // Two columns when there is room, so 8 controls fit without much
        // scrolling on a 360-411 px tall landscape phone.
        const gap = 8.0;
        final columns =
            constraints.maxWidth >=
                440 * MediaQuery.textScalerOf(context).scale(1)
            ? 2
            : 1;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final group in widget.groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                child: Text(
                  group.title.toUpperCase(),
                  style: const TextStyle(
                    color: LavenderPalette.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final choice in group.choices)
                    SizedBox(
                      width: tileWidth,
                      child: _ChoiceTile(
                        choice: choice,
                        active: widget.isActive(choice.id),
                        onTap: () => _toggle(choice.id),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: CatGlassModalSurface(
              borderRadius: 24,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: LavenderPalette.violet.withValues(
                              alpha: 0.35,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      header,
                      Flexible(
                        child: SingleChildScrollView(
                          child: Material(
                            type: MaterialType.transparency,
                            child: body,
                          ),
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
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.choice,
    required this.active,
    required this.onTap,
  });

  final GamepadControlChoice choice;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    final asset = choice.asset;
    final leading = SizedBox.square(
      dimension: 36,
      child: asset != null
          ? Image.asset(
              asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.radio_button_unchecked_rounded,
                color: LavenderPalette.violet,
              ),
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: LavenderPalette.violet.withValues(alpha: 0.12),
              ),
              child: Icon(choice.icon, size: 22, color: LavenderPalette.violet),
            ),
    );
    return Semantics(
      button: true,
      toggled: active,
      label: active ? '${choice.label}, on the pad' : '${choice.label}, hidden',
      excludeSemantics: true,
      child: Material(
        color: active
            ? LavenderPalette.violet.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: active
                ? LavenderPalette.violet.withValues(alpha: 0.45)
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: LavenderPalette.violet.withValues(alpha: 0.10),
          highlightColor: LavenderPalette.violet.withValues(alpha: 0.05),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
              child: Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      choice.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LavenderPalette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.add_circle_outline_rounded,
                    size: 24,
                    color: active
                        ? LavenderPalette.violet
                        : LavenderPalette.inkMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
