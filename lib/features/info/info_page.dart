// lib/features/info/info_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui/custom_appbars.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

enum _InfoLang { en, th }

class _InfoPageState extends State<InfoPage> {
  _InfoLang _lang = _InfoLang.en;

  @override
  Widget build(BuildContext context) {
    final isThai = _lang == _InfoLang.th;
    return Scaffold(
      appBar: SimpleAppBar(
        title: isThai ? 'คู่มือ' : 'Guide',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ToggleButtons(
              isSelected: [_lang == _InfoLang.en, _lang == _InfoLang.th],
              onPressed: (index) {
                setState(() {
                  _lang = index == 0 ? _InfoLang.en : _InfoLang.th;
                });
              },
              borderRadius: BorderRadius.circular(8),
              color: Colors.white70,
              selectedColor: Colors.white,
              fillColor: Colors.white24,
              constraints: const BoxConstraints(minHeight: 28, minWidth: 40),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('ENG', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('TH', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: isThai ? _buildThai() : _buildEnglish(),
      ),
    );
  }
}

List<Widget> _buildEnglish() {
  return const [
    _SectionTitle('Overview'),
    _BodyText(
      'This app talks to an ESP32 BLE board using the KB-BLE library. '
      'Other boards can follow through Serial if they do not support BLE.',
    ),
    _SectionTitle('Requirements'),
    _BulletText('ESP32/ESP32-C3/S3 (BLE supported)'),
    _BulletText('KB-BLE library installed on Arduino/KBIDE'),
    _BulletText('BLE name in code must match the app'),
    _SectionTitle('Install PB-BLE (Arduino IDE)'),
    _BulletText('Go to'),
    _LinkBullet('https://github.com/Amornthep-ra/PB-BLE'),
    _BulletText('Code -> Download ZIP'),
    _BulletText('Arduino IDE: Sketch -> Include Library -> Add .ZIP Library'),
    _BulletText('Restart Arduino IDE if the library does not appear'),
    _SectionTitle('KB-IDE'),
    _BodyText(
      'KB-IDE is a beginner-friendly block-based IDE for programming our boards, '
      'similar to Scratch/Blockly but for Arduino-compatible devices.',
    ),
    _BulletText('Tutorials and device guides:'),
    _LinkBullet('https://www.princebotshop.com/blog'),
    _SectionTitle('Gamepad Mode Edit (8 Button)'),
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
    _SectionTitle('Gamepad 4 Button'),
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
    _SectionTitle('Joystick'),
    _CodeBlock(
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
    _SectionTitle('Buttons Bit Map'),
    _CodeBlock(
      'Buttons (low byte)\n'
      'Up=1  Down=2  Left=4  Right=8\n'
      'Triangle=16  Cross=32  Square=64  Circle=128\n'
      '\n'
      'Speed level (high byte)\n'
      'Lo=1  Med=2  Hi=4\n',
    ),
    _SectionTitle('Notes'),
    _BulletText('Use bitwise AND to check button combos.'),
    _BulletText('Keep BLE loop fast; update display less often.'),
  ];
}

List<Widget> _buildThai() {
  return const [
    _SectionTitle('ภาพรวม'),
    _BodyText(
      'แอปนี้สื่อสารกับบอร์ด ESP32 ผ่าน BLE โดยใช้ไลบรารี KB-BLE '
      'หากบอร์ดไม่รองรับ BLE สามารถส่งต่อผ่าน Serial ได้',
    ),
    _SectionTitle('สิ่งที่ต้องมี'),
    _BulletText('ESP32/ESP32-C3/S3 (รองรับ BLE)'),
    _BulletText('ติดตั้งไลบรารี KB-BLE ใน Arduino/KBIDE'),
    _BulletText('ชื่อ BLE ในโค้ดต้องตรงกับในแอป'),
    _SectionTitle('ติดตั้ง PB-BLE (Arduino IDE)'),
    _BulletText('เข้าไปที่'),
    _LinkBullet('https://github.com/Amornthep-ra/PB-BLE'),
    _BulletText('กด Code -> Download ZIP'),
    _BulletText('Arduino IDE: Sketch -> Include Library -> Add .ZIP Library'),
    _BulletText('ถ้าไม่ขึ้นให้ปิดแล้วเปิด Arduino IDE ใหม่'),
    _SectionTitle('KB-IDE'),
    _BodyText(
      'KB-IDE คือโปรแกรมเขียนโค้ดแบบบล็อก ใช้งานง่าย '
      'คล้าย Scratch/Blockly แต่ใช้กับบอร์ด Arduino ได้',
    ),
    _BulletText('บทความและคู่มืออุปกรณ์:'),
    _LinkBullet('https://www.princebotshop.com/blog'),
    _SectionTitle('Gamepad Mode Edit (8 ปุ่ม)'),
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
    _SectionTitle('Gamepad 4 ปุ่ม'),
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
    _SectionTitle('Joystick'),
    _CodeBlock(
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
    _SectionTitle('ปุ่มที่ใช้ (Bit Map)'),
    _CodeBlock(
      'ปุ่ม (low byte)\n'
      'Up=1  Down=2  Left=4  Right=8\n'
      'Triangle=16  Cross=32  Square=64  Circle=128\n'
      '\n'
      'ระดับความเร็ว (high byte)\n'
      'Lo=1  Med=2  Hi=4\n',
    ),
    _SectionTitle('หมายเหตุ'),
    _BulletText('ใช้ bit AND เพื่อตรวจสอบการกดปุ่มพร้อมกัน'),
    _BulletText('ควรอัปเดต BLE ให้ถี่ และอัปเดตหน้าจอให้น้อยลง'),
  ];
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.4,
            ),
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;
  const _BulletText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkBullet extends StatelessWidget {
  final String url;
  const _LinkBullet(this.url);

  Future<void> _openUrl() async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyUrl(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: InkWell(
              onTap: _openUrl,
              onLongPress: () => _copyUrl(context),
              child: Text(
                url,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: color,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
          ),
        ],
      ),
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

