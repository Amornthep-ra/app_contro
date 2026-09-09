import 'package:flutter/material.dart';

class GamepadCatChoiceTile extends StatelessWidget {
  final String asset;
  final String label;
  final String? value;
  final Color accent;
  final bool selected;
  final VoidCallback? onTap;
  final double selectedOpacity;
  final double unselectedOpacity;
  final double iconSize;
  final bool horizontal;

  const GamepadCatChoiceTile({
    super.key,
    required this.asset,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.value,
    this.selectedOpacity = 1,
    this.unselectedOpacity = .78,
    this.iconSize = 38,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = selected
        ? accent
        : theme.colorScheme.onSurface.withAlpha(190);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: selected ? selectedOpacity : unselectedOpacity,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: selected ? 0.95 : 1,
        child: Material(
          color: selected ? accent.withAlpha(34) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              constraints: const BoxConstraints(minWidth: 64, minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? accent.withAlpha(220) : accent.withAlpha(80),
                  width: selected ? 1.8 : 1,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(95),
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: horizontal
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildIcon(),
                        const SizedBox(width: 5),
                        _buildLabel(textColor),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [_buildIcon(), _buildLabel(textColor)],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Image.asset(
      asset,
      width: iconSize,
      height: iconSize,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.speed_rounded,
        size: iconSize,
        color: accent,
      ),
    );
  }

  Widget _buildLabel(Color textColor) {
    return Text(
      value == null ? label : '$label  $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: textColor,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class GamepadCatValueHeader extends StatelessWidget {
  final String asset;
  final String label;
  final int value;
  final Color accent;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const GamepadCatValueHeader({
    super.key,
    required this.asset,
    required this.label,
    required this.value,
    required this.accent,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          asset,
          width: 32,
          height: 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.tune_rounded,
            size: 24,
            color: accent,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Decrease $label by 5',
          onPressed: onDecrease,
          icon: const Icon(Icons.remove_rounded, size: 15),
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          padding: EdgeInsets.zero,
        ),
        Text(
          '$value%',
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        IconButton(
          tooltip: 'Increase $label by 5',
          onPressed: onIncrease,
          icon: const Icon(Icons.add_rounded, size: 15),
          constraints: const BoxConstraints.tightFor(width: 28, height: 28),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}
