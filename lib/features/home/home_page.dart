// lib/features/home/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../core/widgets/logo_corner.dart';
import '../../core/ui/theme_controller.dart';
import '../../core/ui/language_controller.dart';
import '../controller/controller_home_page.dart';
import '../linesonic/linesonic_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PB Controller',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 5,
        shadowColor: Colors.black54,
        backgroundColor: Colors.transparent,
        leadingWidth: 96,
        leading: ValueListenableBuilder<bool>(
          valueListenable: LanguageController.isThai,
          builder: (context, isThai, _) {
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: ToggleButtons(
                isSelected: [!isThai, isThai],
                onPressed: (index) {
                  LanguageController.setIsThai(index == 1);
                },
                borderRadius: BorderRadius.circular(8),
                color: Colors.white70,
                selectedColor: Colors.white,
                fillColor: Colors.white24,
                constraints: const BoxConstraints(minHeight: 24, minWidth: 32),
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('EN',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('TH',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.color_lens_outlined, color: Colors.white),
            onPressed: () => _showThemeSheet(context),
            tooltip: 'Theme',
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0083FF), Color(0xFF0051A8)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: LanguageController.isThai,
            builder: (context, isThai, _) {
              final items = <_HomeItem>[
                _HomeItem(
                  'Controller',
                  isThai ? 'รวมฟังก์ชันควบคุมพื้นฐาน' : 'Classic controller features',
                  Icons.gamepad,
                  const ControllerHomePage(),
                ),
                _HomeItem(
                  'LineSonic',
                  isThai ? 'ปรับค่า PID ผ่าน BLE' : 'PID tuning over BLE',
                  Icons.timeline,
                  const LineSonicPage(),
                ),
              ];

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _HomeCard(item: it, accent: _accentFor(index));
                },
              );
            },
          ),
          const LogoCorner(),
        ],
      ),
    );
  }

  Color _accentFor(int index) {
    if (index == 0) return const Color(0xFF0EA5E9);
    return const Color(0xFF22C55E);
  }
}

class _HomeItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _HomeItem(this.title, this.subtitle, this.icon, this.page);
}

class _HomeCard extends StatelessWidget {
  final _HomeItem item;
  final Color accent;

  const _HomeCard({required this.item, required this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.page),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant.withAlpha(80)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_forward,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

void _showThemeSheet(BuildContext context) {
  showCupertinoModalPopup<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return CupertinoActionSheet(
        title: const Text('Theme'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.light);
              Navigator.of(context).pop();
            },
            child: const Text('Light'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              ThemeController.setMode(ThemeMode.dark);
              Navigator.of(context).pop();
            },
            child: const Text('Dark'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      );
    },
  );
}
