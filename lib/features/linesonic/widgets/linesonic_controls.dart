// lib/features/linesonic/widgets/linesonic_controls.dart
import 'package:flutter/material.dart';

import '../../../core/ui/lavender_glass.dart';

/// Small bold caption above a LineSonic control group.
class LineSonicCaption extends StatelessWidget {
  const LineSonicCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: LavenderPalette.inkSoft,
        ),
      ),
    );
  }
}

/// Glass segmented control with 48 px segments.
class LineSonicSegments<T> extends StatelessWidget {
  const LineSonicSegments({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.accent,
  });

  final List<(T, String)> options;
  final T? selected;
  final ValueChanged<T> onSelected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: radius,
        border: Border.all(color: LavenderPalette.ink.withValues(alpha: 0.10)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: Semantics(
                selected: value == selected,
                button: true,
                child: Material(
                  color: value == selected
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: value == selected
                        ? BorderSide(color: accent.withValues(alpha: 0.45))
                        : BorderSide.none,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(value),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 42),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: value == selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: value == selected
                                  ? accent
                                  : LavenderPalette.inkSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
