import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ui/app_assets.dart';
import '../../core/ui/control_mode_preference.dart';
import '../../core/ui/language_controller.dart';

enum ControlMode { fourButton, eightButton, joystick }

enum ControlModeSettingsAction {
  editLayout,
  selectFourButton,
  selectEightButton,
  selectJoystick,
}

PageRouteBuilder<ControlModeSettingsAction> controlModeSettingsRoute({
  required ControlMode mode,
  required FutureOr<void> Function() onManageLayouts,
}) {
  return PageRouteBuilder<ControlModeSettingsAction>(
    transitionDuration: const Duration(milliseconds: 160),
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) =>
        ControlModeSettingsPage(mode: mode, onManageLayouts: onManageLayouts),
    transitionsBuilder: (_, animation, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
      child: child,
    ),
  );
}

class ControlModeSettingsPage extends StatefulWidget {
  const ControlModeSettingsPage({
    super.key,
    required this.mode,
    required this.onManageLayouts,
  });

  final ControlMode mode;
  final FutureOr<void> Function() onManageLayouts;

  @override
  State<ControlModeSettingsPage> createState() =>
      _ControlModeSettingsPageState();
}

class _ControlModeSettingsPageState extends State<ControlModeSettingsPage> {
  late ControlMode _selectedMode;

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.mode;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _closeSettings(context);
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: LanguageController.isThai,
        builder: (context, isThai, _) {
          final labels = _SettingsLabels(isThai);
          return Scaffold(
            backgroundColor: const Color(0xFFF5EDFF),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  AppAssets.controlBackground,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const ColoredBox(color: Color(0xFFF5EDFF)),
                ),
                const _SettingsBackdropDecoration(),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact =
                          constraints.maxHeight < 650 ||
                          constraints.maxWidth < 900;
                      final horizontalPadding = compact ? 12.0 : 18.0;
                      final safeContentWidth =
                          constraints.maxWidth - (horizontalPadding * 2);
                      final textScale = MediaQuery.textScalerOf(
                        context,
                      ).scale(1);
                      final twoColumn =
                          safeContentWidth >= 600 && textScale <= 1.3;
                      final layoutFirst =
                          !twoColumn &&
                          (textScale > 1.3 ||
                              constraints.maxWidth > constraints.maxHeight);
                      return Column(
                        children: [
                          _SettingsHeader(
                            title: labels.settings,
                            backLabel: labels.back,
                            onBack: () => _closeSettings(context),
                            compact: compact,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPadding,
                                compact ? 8 : 12,
                                horizontalPadding,
                                compact ? 16 : 20,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 960,
                                  ),
                                  child: _ResponsiveSettingsSections(
                                    twoColumn: twoColumn,
                                    layoutFirst: layoutFirst,
                                    gap: compact ? 12 : 14,
                                    sections: [
                                      _SettingsSection(
                                        key: const ValueKey(
                                          'control-mode-section',
                                        ),
                                        title: labels.controlMode,
                                        compact: compact,
                                        child: Column(
                                          children: [
                                            _CatSettingsTile.mode(
                                              asset: AppAssets
                                                  .settingsModeFourButton,
                                              title: '4 BTN',
                                              selected:
                                                  _selectedMode ==
                                                  ControlMode.fourButton,
                                              selectedLabel: labels.selected,
                                              compact: compact,
                                              onTap: () => _selectMode(
                                                ControlMode.fourButton,
                                              ),
                                            ),
                                            SizedBox(height: compact ? 5 : 7),
                                            _CatSettingsTile.mode(
                                              asset: AppAssets
                                                  .settingsModeEightButton,
                                              title: '8 BTN',
                                              selected:
                                                  _selectedMode ==
                                                  ControlMode.eightButton,
                                              selectedLabel: labels.selected,
                                              compact: compact,
                                              onTap: () => _selectMode(
                                                ControlMode.eightButton,
                                              ),
                                            ),
                                            SizedBox(height: compact ? 5 : 7),
                                            _CatSettingsTile.mode(
                                              asset: AppAssets
                                                  .settingsModeJoystick,
                                              title: labels.joystick,
                                              selected:
                                                  _selectedMode ==
                                                  ControlMode.joystick,
                                              selectedLabel: labels.selected,
                                              compact: compact,
                                              onTap: () => _selectMode(
                                                ControlMode.joystick,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: compact ? 12 : 14),
                                      _SettingsSection(
                                        key: const ValueKey('layout-section'),
                                        title: labels.layout,
                                        compact: compact,
                                        child: Column(
                                          children: [
                                            _CatSettingsTile.action(
                                              asset:
                                                  AppAssets.settingsEditLayout,
                                              title: labels.editLayout,
                                              trailingLabel: labels.open,
                                              compact: compact,
                                              onTap: () =>
                                                  _openEditLayout(context),
                                            ),
                                            SizedBox(height: compact ? 5 : 7),
                                            _CatSettingsTile.action(
                                              asset: AppAssets
                                                  .settingsSavedLayouts,
                                              title: labels.savedLayouts,
                                              trailingLabel: labels.open,
                                              compact: compact,
                                              onTap: () => _runCallback(
                                                widget.onManageLayouts,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectMode(ControlMode mode) {
    if (_selectedMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedMode = mode);
    unawaited(
      ControlModePreference.save(switch (mode) {
        ControlMode.fourButton => LastControlMode.fourButton,
        ControlMode.eightButton => LastControlMode.eightButton,
        ControlMode.joystick => LastControlMode.joystick,
      }),
    );
  }

  void _closeSettings(BuildContext context) {
    Navigator.of(context).pop(_actionForSelectedMode());
  }

  ControlModeSettingsAction? _actionForSelectedMode() {
    if (_selectedMode == widget.mode) return null;
    return switch (_selectedMode) {
      ControlMode.fourButton => ControlModeSettingsAction.selectFourButton,
      ControlMode.eightButton => ControlModeSettingsAction.selectEightButton,
      ControlMode.joystick => ControlModeSettingsAction.selectJoystick,
    };
  }

  Future<void> _runCallback(FutureOr<void> Function() callback) async {
    HapticFeedback.selectionClick();
    await callback();
  }

  void _openEditLayout(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(ControlModeSettingsAction.editLayout);
  }
}

class _ResponsiveSettingsSections extends StatelessWidget {
  const _ResponsiveSettingsSections({
    required this.twoColumn,
    required this.layoutFirst,
    required this.gap,
    required this.sections,
  });

  final bool twoColumn;
  final bool layoutFirst;
  final double gap;
  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    final mode = sections.first;
    final layout = sections.last;
    if (twoColumn) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: mode),
          const SizedBox(width: 16),
          Expanded(child: layout),
        ],
      );
    }
    return Column(
      children: [
        if (layoutFirst) layout else mode,
        SizedBox(height: gap),
        if (layoutFirst) mode else layout,
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.title,
    required this.backLabel,
    required this.onBack,
    required this.compact,
  });

  final String title;
  final String backLabel;
  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact ? 52.0 : 62.0;
    return Container(
      constraints: BoxConstraints(minHeight: height),
      width: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: compact ? 10 : 24,
            child: Semantics(
              button: true,
              label: backLabel,
              child: Tooltip(
                message: backLabel,
                child: InkResponse(
                  onTap: onBack,
                  radius: 30,
                  child: SizedBox(
                    width: compact ? 50 : 54,
                    height: compact ? 50 : 54,
                    child: Image.asset(
                      AppAssets.controlBack,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF4B2A86),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: compact ? 220 : 300,
                minHeight: compact ? 40 : 48,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(126),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withAlpha(220)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC084FC).withAlpha(92),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF4B278B),
                  fontSize: compact ? 20 : 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    super.key,
    required this.title,
    required this.child,
    required this.compact,
  });

  final String title;
  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tabHeight = compact ? 26.0 : 30.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: tabHeight * .56),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(compact ? 18 : 22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  compact ? 8 : 12,
                  tabHeight * .70,
                  compact ? 8 : 12,
                  compact ? 8 : 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(104),
                  borderRadius: BorderRadius.circular(compact ? 18 : 22),
                  border: Border.all(color: Colors.white.withAlpha(180)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withAlpha(44),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: compact ? 16 : 20,
          child: Container(
            constraints: BoxConstraints(minHeight: tabHeight),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 15 : 20,
              vertical: compact ? 3 : 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF8270D9).withAlpha(224),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
                bottom: Radius.circular(14),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D4CCB).withAlpha(80),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 13 : 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _SettingsTileTrailing { selection, chevron }

class _CatSettingsTile extends StatelessWidget {
  const _CatSettingsTile._({
    required this.asset,
    required this.title,
    required this.onTap,
    required this.trailing,
    required this.selected,
    required this.selectedLabel,
    required this.trailingLabel,
    required this.compact,
  });

  factory _CatSettingsTile.mode({
    required String asset,
    required String title,
    required bool selected,
    required String selectedLabel,
    required bool compact,
    required VoidCallback onTap,
  }) => _CatSettingsTile._(
    asset: asset,
    title: title,
    onTap: onTap,
    trailing: _SettingsTileTrailing.selection,
    selected: selected,
    selectedLabel: selectedLabel,
    compact: compact,
    trailingLabel: '',
  );

  factory _CatSettingsTile.action({
    required String asset,
    required String title,
    required String trailingLabel,
    required bool compact,
    required VoidCallback onTap,
  }) => _CatSettingsTile._(
    asset: asset,
    title: title,
    onTap: onTap,
    trailing: _SettingsTileTrailing.chevron,
    selected: false,
    selectedLabel: '',
    compact: compact,
    trailingLabel: trailingLabel,
  );

  final String asset;
  final String title;
  final VoidCallback onTap;
  final _SettingsTileTrailing trailing;
  final bool selected;
  final String selectedLabel;
  final String trailingLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFFF472D0);
    final semanticLabel = selected ? '$title, $selectedLabel' : title;
    final tileHeight = compact ? 56.0 : 66.0;
    final iconSize = compact ? 40.0 : 48.0;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: tileHeight),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFEEF9).withAlpha(210)
                    : Colors.white.withAlpha(148),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? accent.withAlpha(230) : Colors.white,
                  width: selected ? 2 : 1.2,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: accent.withAlpha(105),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    padding: EdgeInsets.all(compact ? 4 : 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(138),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withAlpha(210)),
                    ),
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        trailing == _SettingsTileTrailing.selection
                            ? Icons.gamepad_rounded
                            : Icons.tune_rounded,
                        color: const Color(0xFF7655B7),
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 10 : 14),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: Color(0xFF39206D),
                        fontSize: compact ? 16 : 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 6 : 10),
                  _buildTrailing(accent, compact),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailing(Color accent, bool compact) {
    if (trailing == _SettingsTileTrailing.chevron) {
      return Semantics(
        label: trailingLabel,
        child: Icon(
          Icons.chevron_right_rounded,
          size: compact ? 24 : 30,
          color: Color(0xFF8063C2),
        ),
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: compact ? 30 : 34,
      height: compact ? 30 : 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? accent : Colors.transparent,
        border: Border.all(
          color: selected ? accent : const Color(0xFFB8A8E7),
          width: 2.5,
        ),
        boxShadow: selected
            ? [BoxShadow(color: accent.withAlpha(156), blurRadius: 14)]
            : const [],
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: compact ? 20 : 24,
            )
          : null,
    );
  }
}

class _SettingsBackdropDecoration extends StatelessWidget {
  const _SettingsBackdropDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: const [
          Positioned(left: 44, top: 132, child: _PawDecoration(size: 26)),
          Positioned(right: 54, top: 180, child: _PawDecoration(size: 34)),
          Positioned(left: 82, bottom: 38, child: _PawDecoration(size: 32)),
          Positioned(right: 92, bottom: 44, child: _PawDecoration(size: 24)),
        ],
      ),
    );
  }
}

class _PawDecoration extends StatelessWidget {
  const _PawDecoration({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.pets_rounded,
      size: size,
      color: Colors.white.withAlpha(116),
    );
  }
}

class _SettingsLabels {
  const _SettingsLabels(this.isThai);

  final bool isThai;

  String get settings => isThai ? 'Settings' : 'Settings';
  String get back => isThai ? 'Back' : 'Back';
  String get controlMode => isThai ? 'Control mode' : 'Control mode';
  String get layout => isThai ? 'Layout' : 'Layout';
  String get joystick => isThai ? 'Joystick' : 'Joystick';
  String get editLayout => isThai ? 'Edit layout' : 'Edit layout';
  String get savedLayouts => isThai ? 'Saved layouts' : 'Saved layouts';
  String get selected => isThai ? 'selected' : 'selected';
  String get open => isThai ? 'Open' : 'Open';
}
