import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/language_controller.dart';
import '../../core/widgets/gamepad_app_bar.dart';
import '../../core/widgets/portrait_background.dart';
import 'gamepad_4_button_page.dart';
import 'gamepad_mode_edit.dart';

class GamepadModePickerPage extends StatelessWidget {
  const GamepadModePickerPage({super.key});

  void _openMode(BuildContext context, Widget page) {
    HapticFeedback.selectionClick();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: GamepadUnifiedAppBar(
            leading: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: 'Gamepad',
            centerTitle: true,
            useGlassBackground: false,
            titleStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          body: PortraitBackground(
            child: Padding(
              padding: EdgeInsets.only(
                top:
                    MediaQuery.paddingOf(context).top +
                    GamepadAppBarMetrics.toolbarHeight,
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isThai
                            ? 'Choose a control mode'
                            : 'Choose a control mode',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isThai
                            ? 'You can switch modes while controlling.'
                            : 'You can switch modes while controlling.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 20),
                      _ModeChoiceCard(
                        icon: Icons.tune_rounded,
                        title: '8 BTN',
                        description: isThai
                            ? 'Tune DRV and TRN with an editable 8-button layout.'
                            : 'Tune DRV and TRN with an editable 8-button layout.',
                        color: const Color(0xFF8B5CF6),
                        onTap: () =>
                            _openMode(context, const GamepadModeEdit()),
                      ),
                      const SizedBox(height: 12),
                      _ModeChoiceCard(
                        icon: Icons.gamepad_rounded,
                        title: '4 BTN',
                        description: isThai
                            ? 'Use 4 directional buttons with Low, Med, and Hi speeds.'
                            : 'Use 4 directional buttons with Low, Med, and Hi speeds.',
                        color: const Color(0xFF3B82F6),
                        onTap: () =>
                            _openMode(context, const Gamepad4ButtonPage()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ModeChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final VoidCallback onTap;

  const _ModeChoiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withAlpha(96)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
