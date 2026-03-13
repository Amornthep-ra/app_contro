// lib/features/linesonic/linesonic_page.dart
import 'package:flutter/cupertino.dart' hide Text;
import 'package:flutter/material.dart';
import '../../core/ui/language_controller.dart';
import '../../core/routes/app_routes.dart';
import 'linesonic_pid_page.dart';
import 'linesonic_sensor_page.dart';

class LineSonicPage extends StatelessWidget {
  const LineSonicPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final items = [
          _LineSonicItem(
            title: 'PID Tuning',
            subtitle: isThai ? 'ปรับค่า KP/KD/Speed ผ่าน BLE' : 'Tune KP/KD/Speed over BLE',
            icon: Icons.tune,
            page: const LineSonicPidPage(),
          ),
          _LineSonicItem(
            title: 'Read Sensor',
            subtitle: isThai ? 'อ่านค่าเซนเซอร์จากบอร์ด' : 'Read sensor values from board',
            icon: Icons.sensors,
            page: const LineSonicSensorPage(),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('LineSonic'),
            automaticallyImplyLeading: false,
          ),
          body: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final it = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => it.page),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(it.icon, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              it.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              it.subtitle,
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
            },
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'home_fab_linesonic',
            mini: true,
            onPressed: () => Navigator.popUntil(
              context,
              (route) => route.settings.name == AppRoutes.home || route.isFirst,
            ),
            child: const Icon(Icons.home),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
        );
      },
    );
  }
}

class _LineSonicItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _LineSonicItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.page,
  });
}



