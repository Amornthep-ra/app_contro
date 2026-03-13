// lib/features/info/info_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/ui/language_controller.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  Widget _buildPage(List<Widget> children) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: children.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => children[index],
    );
  }

  Widget _buildPager(BuildContext context, bool isThai) {
    final theme = Theme.of(context);
    final index = _tabController.index + 1;
    final total = _tabController.length;
    final canPrev = _tabController.index > 0;
    final canNext = _tabController.index < total - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.4),
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$index / $total',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canPrev
                        ? () => _tabController.animateTo(_tabController.index - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    label: Text(isThai ? 'ก่อนหน้า' : 'Previous'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: canNext
                        ? () => _tabController.animateTo(_tabController.index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    label: Text(isThai ? 'ถัดไป' : 'Next'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: LanguageController.isThai,
      builder: (context, isThai, _) {
        final tabs = <Tab>[
          Tab(child: Text(isThai ? 'ภาพรวม' : 'Overview')),
          const Tab(child: Text('Controller')),
          const Tab(child: Text('LineSonic')),
        ];

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: 48,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            centerTitle: true,
            leading: Navigator.of(context).canPop()
                ? const BackButton(color: Colors.white)
                : null,
            title: Text(
              isThai ? 'คู่มือ' : 'Guide',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelPadding: EdgeInsets.zero,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    indicator: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    tabs: tabs,
                  ),
                ),
              ),
            ),
            flexibleSpace: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF37474F), Color(0xFF546E7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPage(isThai ? _buildOverviewThai() : _buildOverviewEnglish()),
                    _buildPage(isThai ? _buildPbBleThai() : _buildPbBleEnglish()),
                    _buildPage(isThai ? _buildLineSonicThai() : _buildLineSonicEnglish()),
                  ],
                ),
              ),
              _buildPager(context, isThai),
            ],
          ),
        );
      },
    );
  }
}

List<Widget> _buildOverviewEnglish() {
  return [
    _InfoCard(
      title: 'Overview',
      icon: Icons.info_outline,
      children: const [
        _InfoParagraph(
          'This guide explains how to use the app to control ESP32 boards and tune LineSonic '
          'via Bluetooth (BLE) or Serial.',
        ),
      ],
    ),
    _InfoCard(
      title: 'Requirements',
      icon: Icons.fact_check,
      children: const [
        _InfoTile('ESP32/ESP32-C3/S3 with Bluetooth (BLE)'),
        _InfoTile('PB-BLE + Line Follower library installed in Arduino IDE or KBIDE'),
      ],
    ),
    _InfoCard(
      title: 'KB-IDE',
      icon: Icons.school_outlined,
      children: const [
        _InfoParagraph(
          'KB-IDE is a beginner-friendly block-based IDE for our boards, similar to '
          'Scratch/Blockly but for Arduino-compatible devices.',
        ),
        _LinkTile(label: 'Download KB-IDE', url: 'https://www.princebot.co.th'),
        _LinkTile(
          label: 'Tutorials and device guides',
          url: 'https://www.princebotshop.com/blog',
        ),
        _LinkTile(
          label: 'PrinceBot Facebook',
          url: 'https://www.facebook.com/PrinceBotAndElectronics',
        ),
      ],
    ),
    _InfoCard(
      title: 'Using the App',
      icon: Icons.touch_app,
      children: [
        _InfoTileRich([
          _t('Tap '),
          _b('Customize'),
          _t(' to add, remove, move, or resize buttons and joysticks.'),
        ]),
        _InfoTileRich([
          _t('Toolbar: '),
          _b('Grid'),
          _t(' snaps positions, '),
          _b('Size'),
          _t(' changes button size, '),
          _b('Lock'),
          _t(' prevents accidental moves.'),
        ]),
        _InfoTileRich([
          _b('Presets'),
          _t(' save and recall layouts quickly.'),
        ]),
        _InfoTileRich([
          _b('Reset Left/Right/All'),
          _t(' restores default positions.'),
        ]),
        const _InfoTile('If the screen is empty, add buttons before use.'),
      ],
    ),
    _InfoCard(
      title: 'BLE Setup',
      icon: Icons.bluetooth,
      children: [
        const _InfoTile('Tap the BLE status bar to open the panel.'),
        _InfoTileRich([
          _t('Press '),
          _b('Scan'),
          _t(' and select a device.'),
        ]),
        _InfoTileRich([
          _t('If Bluetooth is off, the app opens '),
          _i('Settings'),
          _t('.'),
        ]),
        const _InfoTile('Status dot shows connection state (red/green).'),
      ],
    ),
    _InfoCard(
      title: 'Troubleshooting',
      icon: Icons.build_outlined,
      children: const [
        _InfoTile('No devices found: make sure Bluetooth is on and the device is nearby.'),
        _InfoTile('Connect fails: restart the board and try again.'),
        _InfoTile('Buttons not responding: ensure buttons are added and not locked.'),
      ],
    ),
    _InfoCard(
      title: 'Contact / Support',
      icon: Icons.support_agent,
      children: const [
        _EmailTile('amornthep064@gmail.com'),
      ],
    ),
    _InfoCard(
      title: 'App Version',
      icon: Icons.info_outline,
      children: const [
        _AppVersionTile(),
      ],
    ),
  ];
}

List<Widget> _buildOverviewThai() {
  return [
    _InfoCard(
      title: 'ภาพรวม',
      icon: Icons.info_outline,
      children: const [
        _InfoParagraph(
          'คู่มือนี้อธิบายการใช้งานแอปพลิเคชันเพื่อควบคุมบอร์ด ESP32 และปรับค่า LineSonic '
          'ผ่านบลูทูธ (Bluetooth/BLE) หรือ Serial',
        ),
      ],
    ),
    _InfoCard(
      title: 'สิ่งที่ต้องมี',
      icon: Icons.fact_check,
      children: const [
        _InfoTile('บอร์ด ESP32/ESP32-C3/S3 ที่รองรับบลูทูธ (Bluetooth/BLE)'),
        _InfoTile('ติดตั้งไลบรารี PB-BLE + Line Follower ใน Arduino IDE หรือ KBIDE แล้ว'),
      ],
    ),
    _InfoCard(
      title: 'KB-IDE',
      icon: Icons.school_outlined,
      children: const [
        _InfoParagraph(
          'KB-IDE คือโปรแกรมเขียนโค้ดแบบบล็อกสำหรับผู้เริ่มต้น คล้าย Scratch/Blockly '
          'แต่ใช้กับบอร์ดที่รองรับ Arduino',
        ),
        _LinkTile(label: 'ดาวน์โหลด KB-IDE', url: 'https://www.princebot.co.th'),
        _LinkTile(
          label: 'บทเรียนและคู่มืออุปกรณ์',
          url: 'https://www.princebotshop.com/blog',
        ),
        _LinkTile(
          label: 'PrinceBot Facebook',
          url: 'https://www.facebook.com/PrinceBotAndElectronics',
        ),
      ],
    ),
    _InfoCard(
      title: 'การใช้งานแอป',
      icon: Icons.touch_app,
      children: [
        _InfoTileRich([
          _t('แตะ '),
          _b('ปรับแต่งปุ่ม'),
          _t(' เพื่อเพิ่ม ลบ ย้าย หรือปรับขนาดปุ่มและจอยสติ๊ก'),
        ]),
        _InfoTileRich([
          _t('แถบเครื่องมือ: '),
          _b('Grid'),
          _t(' จัดแนวตำแหน่ง, '),
          _b('Size'),
          _t(' ปรับขนาดปุ่ม, '),
          _b('Lock'),
          _t(' ล็อกตำแหน่ง'),
        ]),
        _InfoTileRich([
          _b('ค่าที่ตั้งไว้'),
          _t(' บันทึกและเรียกคืนเลย์เอาต์ได้รวดเร็ว'),
        ]),
        _InfoTileRich([
          _b('รีเซ็ตซ้าย/ขวา/ทั้งหมด'),
          _t(' คืนค่าเริ่มต้น'),
        ]),
        const _InfoTile('หากหน้าจอว่าง ให้เพิ่มปุ่มก่อนใช้งาน'),
      ],
    ),
    _InfoCard(
      title: 'การตั้งค่า BLE',
      icon: Icons.bluetooth,
      children: [
        const _InfoTile('แตะแถบ BLE เพื่อเปิดแผงเชื่อมต่อ'),
        _InfoTileRich([
          _t('กด '),
          _b('ค้นหา'),
          _t(' แล้วเลือกอุปกรณ์ที่ต้องการ'),
        ]),
        _InfoTileRich([
          _t('หากบลูทูธปิด ระบบจะพาไปหน้า '),
          _i('Settings'),
        ]),
        const _InfoTile('จุดสถานะแสดงการเชื่อมต่อ (แดง/เขียว)'),
      ],
    ),
    _InfoCard(
      title: 'การแก้ไขปัญหาเบื้องต้น',
      icon: Icons.build_outlined,
      children: const [
        _InfoTile('ค้นหาอุปกรณ์ไม่เจอ: เปิดบลูทูธและเข้าใกล้อุปกรณ์'),
        _InfoTile('เชื่อมต่อไม่ติด: รีสตาร์ทบอร์ดแล้วลองเชื่อมต่อใหม่'),
        _InfoTile('ปุ่มไม่ตอบสนอง: ตรวจว่าเพิ่มปุ่มแล้วและไม่ได้ล็อกตำแหน่ง'),
      ],
    ),
    _InfoCard(
      title: 'ติดต่อ / สนับสนุน',
      icon: Icons.support_agent,
      children: const [
        _EmailTile('amornthep064@gmail.com'),
      ],
    ),
    _InfoCard(
      title: 'เวอร์ชันแอป',
      icon: Icons.info_outline,
      children: const [
        _AppVersionTile(),
      ],
    ),
  ];
}

List<Widget> _buildPbBleEnglish() {
  return [
    _InfoCard(
      title: 'Download & Install',
      icon: Icons.download_outlined,
      children: [
        const _LinkTile(
          label: 'Download link: PB-BLE + Line Follower (GitHub)',
          url: 'https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower.git',
        ),
        const _InfoTile('For KB-IDE plugins, download directly from the program.'),
        const _InfoTile('KB-IDE block code examples are available in the Examples menu.'),
        const _InfoTile('Arduino IDE: Sketch -> Include Library -> Add .ZIP Library'),
        const _InfoTile('Restart Arduino IDE if the library does not appear'),
        _InfoTileRich([
          _t('Open '),
          _mono('examples_arduino'),
          _t(' and upload the '),
          _mono('.ino'),
          _t(' you need.'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'Gamepad Mode Edit (8 Button)',
      icon: Icons.videogame_asset_outlined,
      children: const [
        _InfoParagraph('Example for reading 8 buttons and drive/turn speeds.'),
        _CodeBlock(
          '#include "PBGamepad.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  int drv = PB_GetDriveSpeed();\n'
          '  int trn = PB_GetTurnSpeed();\n'
          '\n'
          '  if ((btn & 0x01) && (btn & 0x04)) {\n'
          '    // Up + Left\n'
          '  } else if (btn & 0x01) {\n'
          '    // Up\n'
          '  } else if (btn & 0x02) {\n'
          '    // Down\n'
          '  } else if (btn & 0x04) {\n'
          '    // Left\n'
          '  } else if (btn & 0x08) {\n'
          '    // Right\n'
          '  }\n'
          '\n'
          '  if (btn & 0x10) {\n'
          '    // Triangle\n'
          '  } else if (btn & 0x20) {\n'
          '    // Cross\n'
          '  } else if (btn & 0x40) {\n'
          '    // Square\n'
          '  } else if (btn & 0x80) {\n'
          '    // Circle\n'
          '  }\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Gamepad 4 Button',
      icon: Icons.grid_on,
      children: const [
        _InfoParagraph('Example for 4-button mapping and speed levels.'),
        _CodeBlock(
          '#include "PBGamepad.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  uint8_t level = PB_GetSpeedLevel();\n'
          '  int spd = PB_SpeedFromLevel(level);\n'
          '\n'
          '  // 4-button mapping\n'
          '  if (btn & 0x01) {\n'
          '    // Up\n'
          '  } else if (btn & 0x02) {\n'
          '    // Down\n'
          '  } else if (btn & 0x04) {\n'
          '    // Left\n'
          '  } else if (btn & 0x08) {\n'
          '    // Right\n'
          '  }\n'
          '\n'
          '  if (level & 0x01) {\n'
          '    // Lo\n'
          '  } else if (level & 0x02) {\n'
          '    // Med\n'
          '  } else if (level & 0x04) {\n'
          '    // Hi\n'
          '  }\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Joystick',
      icon: Icons.sports_esports,
      children: [
        _InfoTileRich([
          _t('Go to '),
          _b('Customize'),
          _t(' -> Items to add or remove joysticks and buttons.'),
        ]),
        const _InfoTile('JL/JR show joystick X,Y values (range -1.00 to 1.00).'),
        const _InfoTile('Cmd is a bitmask; pressing multiple buttons adds values together.'),
        const _InfoTile('Joystick (Y only): locks X at 0, moves only up/down.'),
        const _InfoTile('Joystick (X only): locks Y at 0, moves only left/right.'),
        const _CodeBlock(
          '#include "PBGamepad.h"\n'
          '#include "PBJoystick.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  PB_JoystickDual_updateAxes();\n'
          '  int lx = PB_JoystickDual_getLX100();\n'
          '  int ly = PB_JoystickDual_getLY100();\n'
          '  int rx = PB_JoystickDual_getRX100();\n'
          '  int ry = PB_JoystickDual_getRY100();\n'
          '\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  if (btn & 0x10) {\n'
          '    // Triangle\n'
          '  } else if (btn & 0x20) {\n'
          '    // Cross\n'
          '  } else if (btn & 0x40) {\n'
          '    // Square\n'
          '  } else if (btn & 0x80) {\n'
          '    // Circle\n'
          '  }\n'
          '\n'
          '  // use lx/ly/rx/ry to drive motors\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Buttons Bit Map',
      icon: Icons.list_alt,
      children: const [
        _CodeBlock(
          'Buttons (low byte)\n'
          'Up=1  Down=2  Left=4  Right=8\n'
          'Triangle=16  Cross=32  Square=64  Circle=128\n'
          '\n'
          'Speed level (high byte)\n'
          'Lo=1  Med=2  Hi=4\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Notes',
      icon: Icons.sticky_note_2_outlined,
      children: const [
        _InfoTile('Use bitwise AND to check button combos.'),
        _InfoTile('Keep BLE loop fast; update display less often.'),
      ],
    ),
  ];
}

List<Widget> _buildPbBleThai() {
  return [
    _InfoCard(
      title: 'ดาวน์โหลดและติดตั้ง',
      icon: Icons.download_outlined,
      children: [
        const _LinkTile(
          label: 'ลิงก์ดาวน์โหลดโค้ด PB-BLE + Line Follower (GitHub)',
          url: 'https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower.git',
        ),
        const _InfoTile('ปลั๊กอินของ KBIDE สามารถดาวน์โหลดได้จากในโปรแกรมโดยตรง'),
        const _InfoTile('ตัวอย่างโค้ดบล็อกของ KBIDE มีอยู่ในเมนู Examples ของโปรแกรม'),
        const _InfoTile('Arduino IDE: Sketch -> Include Library -> Add .ZIP Library'),
        const _InfoTile('หากไม่พบไลบรารี ให้ปิดแล้วเปิด Arduino IDE ใหม่'),
        _InfoTileRich([
          _t('เปิดโฟลเดอร์ '),
          _mono('examples_arduino'),
          _t(' และอัปโหลดไฟล์ '),
          _mono('.ino'),
          _t(' ที่ต้องการ'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'Gamepad Mode Edit (8 ปุ่ม)',
      icon: Icons.videogame_asset_outlined,
      children: const [
        _InfoParagraph('ตัวอย่างอ่านค่าปุ่ม 8 ปุ่ม และความเร็วขับเคลื่อน/เลี้ยว'),
        _CodeBlock(
          '#include "PBGamepad.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  int drv = PB_GetDriveSpeed();\n'
          '  int trn = PB_GetTurnSpeed();\n'
          '\n'
          '  if ((btn & 0x01) && (btn & 0x04)) {\n'
          '    // Up + Left\n'
          '  } else if (btn & 0x01) {\n'
          '    // Up\n'
          '  } else if (btn & 0x02) {\n'
          '    // Down\n'
          '  } else if (btn & 0x04) {\n'
          '    // Left\n'
          '  } else if (btn & 0x08) {\n'
          '    // Right\n'
          '  }\n'
          '\n'
          '  if (btn & 0x10) {\n'
          '    // Triangle\n'
          '  } else if (btn & 0x20) {\n'
          '    // Cross\n'
          '  } else if (btn & 0x40) {\n'
          '    // Square\n'
          '  } else if (btn & 0x80) {\n'
          '    // Circle\n'
          '  }\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Gamepad 4 ปุ่ม',
      icon: Icons.grid_on,
      children: const [
        _InfoParagraph('ตัวอย่างสำหรับปุ่ม 4 ทิศทางและระดับความเร็ว'),
        _CodeBlock(
          '#include "PBGamepad.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  uint8_t level = PB_GetSpeedLevel();\n'
          '  int spd = PB_SpeedFromLevel(level);\n'
          '\n'
          '  // 4-button mapping\n'
          '  if (btn & 0x01) {\n'
          '    // Up\n'
          '  } else if (btn & 0x02) {\n'
          '    // Down\n'
          '  } else if (btn & 0x04) {\n'
          '    // Left\n'
          '  } else if (btn & 0x08) {\n'
          '    // Right\n'
          '  }\n'
          '\n'
          '  if (level & 0x01) {\n'
          '    // Lo\n'
          '  } else if (level & 0x02) {\n'
          '    // Med\n'
          '  } else if (level & 0x04) {\n'
          '    // Hi\n'
          '  }\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'Joystick',
      icon: Icons.sports_esports,
      children: [
        _InfoTileRich([
          _t('ไปที่ '),
          _b('ปรับแต่งปุ่ม'),
          _t(' -> เลือกใช้งานปุ่ม เพื่อเพิ่ม/ลบจอยสติ๊กหรือปุ่ม'),
        ]),
        const _InfoTile('JL/JR แสดงค่าแกน X,Y ของจอยสติ๊ก (ช่วง -1.00 ถึง 1.00)'),
        const _InfoTile('Cmd เป็นบิตแมสก์ กดหลายปุ่มพร้อมกันจะรวมค่าเข้าด้วยกัน'),
        const _InfoTile('Joystick (Y only): ล็อกค่า X เป็น 0 เคลื่อนที่ขึ้น/ลงเท่านั้น'),
        const _InfoTile('Joystick (X only): ล็อกค่า Y เป็น 0 เคลื่อนที่ซ้าย/ขวาเท่านั้น'),
        const _CodeBlock(
          '#include "PBGamepad.h"\n'
          '#include "PBJoystick.h"\n'
          '\n'
          'void setup() {\n'
          '  Serial.begin(115200);\n'
          '  PBGamepad_init("PB-01");\n'
          '}\n'
          '\n'
          'void loop() {\n'
          '  PB_JoystickDual_updateAxes();\n'
          '  int lx = PB_JoystickDual_getLX100();\n'
          '  int ly = PB_JoystickDual_getLY100();\n'
          '  int rx = PB_JoystickDual_getRX100();\n'
          '  int ry = PB_JoystickDual_getRY100();\n'
          '\n'
          '  uint8_t btn = PB_GetButtonsLow();\n'
          '  if (btn & 0x10) {\n'
          '    // Triangle\n'
          '  } else if (btn & 0x20) {\n'
          '    // Cross\n'
          '  } else if (btn & 0x40) {\n'
          '    // Square\n'
          '  } else if (btn & 0x80) {\n'
          '    // Circle\n'
          '  }\n'
          '\n'
          '  // use lx/ly/rx/ry to drive motors\n'
          '}\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'แผนผังปุ่ม (Bit Map)',
      icon: Icons.list_alt,
      children: const [
        _CodeBlock(
          'ปุ่ม (low byte)\n'
          'Up=1  Down=2  Left=4  Right=8\n'
          'Triangle=16  Cross=32  Square=64  Circle=128\n'
          '\n'
          'ระดับความเร็ว (high byte)\n'
          'Lo=1  Med=2  Hi=4\n',
        ),
      ],
    ),
    _InfoCard(
      title: 'หมายเหตุ',
      icon: Icons.sticky_note_2_outlined,
      children: const [
        _InfoTile('ใช้ bitwise AND เพื่อตรวจการกดปุ่มพร้อมกัน'),
        _InfoTile('ให้ลูป BLE ทำงานเร็ว และลดความถี่การอัปเดตจอ'),
      ],
    ),
  ];
}

List<Widget> _buildLineSonicEnglish() {
  return [
    _InfoCard(
      title: 'Download & Examples',
      icon: Icons.download_outlined,
      children: [
        const _LinkTile(
          label: 'Download link: LineSonic (GitHub)',
          url: 'https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower',
        ),
        const _InfoTile('For KB-IDE plugins, download directly from the program.'),
        const _InfoTile('KB-IDE block code examples are available in the Examples menu.'),
        _InfoTileRich([
          _t('Open: '),
          _mono('Line_Follower_Robot_Arduino/examples_arduino/LineSonic_PID_Tuning/LineSonic_PID_Tuning.ino'),
        ]),
        _InfoTileRich([
          _t('Open: '),
          _mono('Line_Follower_Robot_Arduino/examples_arduino/LineSonic_Read_Sensor/LineSonic_Read_Sensor.ino'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'Hardware Mapping',
      icon: Icons.settings_outlined,
      children: [
        _InfoTileRich([
          _t('Set '),
          _mono('LFR_USE_GENERIC_HW'),
          _t(' in '),
          _mono('LFR_HW_Config.h'),
          _t(' (0 = PB, 1 = Generic).'),
        ]),
        _InfoTileRich([
          _t('Edit pins in '),
          _mono('PB_LineFollowerRobotHW.cpp'),
          _t(' or '),
          _mono('LineFollowerRobotHW.cpp'),
          _t('.'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'Commands',
      icon: Icons.code,
      children: [
        _InfoTileRich([_b('SEQ=...'), _t(' send full step sequence')]),
        _InfoTileRich([_b('SEQPD=...'), _t(' update KP/KD/Speed while running')]),
        _InfoTileRich([_b('SW1=1'), _t(' start/stop')]),
        _InfoTileRich([_b('RESET=1'), _t(' reset')]),
        _InfoTileRich([_b('SENS=1'), _t(' request sensor values')]),
        _InfoTileRich([_t('Response: '), _b('SENS=a,b,c,...,SUM=x')]),
      ],
    ),
    _InfoCard(
      title: 'BLE Name',
      icon: Icons.badge_outlined,
      children: [
        _InfoTileRich([
          _mono('LFR_begin("PB-01")'),
          _t(' should match the app device name.'),
        ]),
      ],
    ),
  ];
}

List<Widget> _buildLineSonicThai() {
  return [
    _InfoCard(
      title: 'ดาวน์โหลดและตัวอย่าง',
      icon: Icons.download_outlined,
      children: [
        const _LinkTile(
          label: 'ลิงก์ดาวน์โหลดโค้ด LineSonic (GitHub)',
          url: 'https://github.com/Amornthep-ra/PB-BLE-And-Line-Follower',
        ),
        const _InfoTile('ปลั๊กอินของ KBIDE สามารถดาวน์โหลดได้จากในโปรแกรมโดยตรง'),
        const _InfoTile('ตัวอย่างโค้ดบล็อกของ KBIDE มีอยู่ในเมนู Examples ของโปรแกรม'),
        _InfoTileRich([
          _t('เปิด: '),
          _mono('Line_Follower_Robot_Arduino/examples_arduino/LineSonic_PID_Tuning/LineSonic_PID_Tuning.ino'),
        ]),
        _InfoTileRich([
          _t('เปิด: '),
          _mono('Line_Follower_Robot_Arduino/examples_arduino/LineSonic_Read_Sensor/LineSonic_Read_Sensor.ino'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'การแมปฮาร์ดแวร์',
      icon: Icons.settings_outlined,
      children: [
        _InfoTileRich([
          _t('ตั้งค่า '),
          _mono('LFR_USE_GENERIC_HW'),
          _t(' ใน '),
          _mono('LFR_HW_Config.h'),
          _t(' (0 = PB, 1 = Generic)'),
        ]),
        _InfoTileRich([
          _t('แก้ไขพินใน '),
          _mono('PB_LineFollowerRobotHW.cpp'),
          _t(' หรือ '),
          _mono('LineFollowerRobotHW.cpp'),
          _t('.'),
        ]),
      ],
    ),
    _InfoCard(
      title: 'คำสั่ง',
      icon: Icons.code,
      children: [
        _InfoTileRich([_b('SEQ=...'), _t(' ส่งลำดับสเต็ปทั้งหมด')]),
        _InfoTileRich([_b('SEQPD=...'), _t(' ปรับค่า KP/KD/Speed ระหว่างทำงาน')]),
        _InfoTileRich([_b('SW1=1'), _t(' เริ่ม/หยุด')]),
        _InfoTileRich([_b('RESET=1'), _t(' รีเซ็ต')]),
        _InfoTileRich([_b('SENS=1'), _t(' ขอค่าเซ็นเซอร์')]),
        _InfoTileRich([_t('ตอบกลับ: '), _b('SENS=a,b,c,...,SUM=x')]),
      ],
    ),
    _InfoCard(
      title: 'ชื่อ BLE',
      icon: Icons.badge_outlined,
      children: [
        _InfoTileRich([
          _mono('LFR_begin("PB-01")'),
          _t(' ควรตรงกับชื่ออุปกรณ์ในแอป'),
        ]),
      ],
    ),
  ];
}

TextSpan _t(String text) => TextSpan(text: text);

TextSpan _b(String text) =>
    TextSpan(text: text, style: const TextStyle(fontWeight: FontWeight.w700));

TextSpan _i(String text) =>
    TextSpan(text: text, style: const TextStyle(fontStyle: FontStyle.italic));

TextSpan _mono(String text) =>
    TextSpan(text: text, style: const TextStyle(fontFamily: 'monospace'));

class _InfoCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoParagraph extends StatelessWidget {
  final String text;
  const _InfoParagraph(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String text;

  const _InfoTile(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 18,
      leading: Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
      title: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
      ),
    );
  }
}

class _InfoTileRich extends StatelessWidget {
  final List<InlineSpan> spans;

  const _InfoTileRich(this.spans);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(height: 1.4);
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 18,
      leading: Icon(Icons.circle, size: 10, color: theme.colorScheme.primary),
      title: Text.rich(TextSpan(style: style, children: spans)),
    );
  }
}

class _LinkTile extends StatelessWidget {
  final String label;
  final String url;

  const _LinkTile({
    required this.label,
    required this.url,
  });

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    final isThai = LanguageController.isThai.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isThai ? 'คัดลอกลิงก์แล้ว' : 'Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 18,
      leading: Icon(Icons.link, size: 18, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      trailing: Icon(
        Icons.open_in_new,
        size: 16,
        color: theme.colorScheme.onSurfaceVariant,
      ),
      onTap: _openUrl,
      onLongPress: () => _copyUrl(context),
    );
  }
}

class _EmailTile extends StatelessWidget {
  final String email;
  const _EmailTile(this.email);

  Future<void> _openEmail() async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    final isThai = LanguageController.isThai.value;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isThai ? 'คัดลอกอีเมลแล้ว' : 'Email copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
      contentPadding: EdgeInsets.zero,
      minLeadingWidth: 18,
      leading:
          Icon(Icons.mail_outline, size: 18, color: theme.colorScheme.primary),
      title: Text(
        email,
        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      onTap: _openEmail,
      onLongPress: () => _copyEmail(context),
    );
  }
}

class _AppVersionTile extends StatelessWidget {
  const _AppVersionTile();

  Future<PackageInfo> _loadInfo() => PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final isThai = LanguageController.isThai.value;
    final theme = Theme.of(context);
    return FutureBuilder<PackageInfo>(
      future: _loadInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final text = info == null ? '-' : '${info.version} (${info.buildNumber})';
        return ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          contentPadding: EdgeInsets.zero,
          minLeadingWidth: 18,
          leading: Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            isThai ? 'เวอร์ชัน: $text' : 'Version: $text',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        );
      },
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD2D9)),
      ),
      child: Text(
        code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          height: 1.35,
          color: Color(0xFF2E2E2E),
        ),
      ),
    );
  }
}

