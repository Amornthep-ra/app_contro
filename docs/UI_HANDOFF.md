# UI Handoff — PB Controller (updated 2026-11-03, LineSonic pages)

> **สรุปสั้น (ไทย):** ปรับ UI ทั้งแอปเป็นธีม "Lavender Glass" แล้ว 5 ส่วน คือ Splash, หน้า Home, หน้า BLE Connection, หน้า Controller (4 BTN / 8 BTN / Joystick) และ **BLE status sheet** (แผ่นที่เปิดจากปุ่ม Bluetooth บน toolbar)
> รอบก่อน: แผงความเร็ว 4/8 BTN ลอยใต้ปุ่ม Speed, หน้า Edit layout (ปุ่มเครื่องมือกดได้เต็ม 48px, กริด 24dp ตรงจุด snap, ปุ่มห่างกันอย่างน้อย 6dp)
> รอบล่าสุด: ทำ BLE status sheet ตามแผนหัวข้อ 7 ครบทุกข้อ (หัวข้อตรงกับ badge, Scanning Ns + Stop, Close เห็นเสมอ, แถวหุ่นยนต์แบบหน้า BLE, Diagnostics แบบ A, Forget อยู่ในเมนู ⋯ และถามก่อน, ปุ่ม 48px)
> จากการทดสอบบนมือถือจริงของเจ้าของ แก้แล้ว 4 ข้อ (หัวข้อ 9): ปุ่ม Start/Stop ไม่ลอยค้างตอนเปลี่ยนโหมด, วงไฮไลต์ Start/Stop ตรงกลางวงกลมจริง, กล่อง Pair Code ใช้ได้ตอนแป้นพิมพ์ขึ้นในแนวนอน, คืนปุ่ม Buttons ใน Edit layout ของ Joystick (ค่าเริ่มต้นยังเป็นจอยซ้าย+ขวา ตามที่เจ้าของเลือก)
> งานทั้งหมดอยู่ใน **PR #2** (`claude/admiring-tesla-o410lj` → `release/2.1.0-android`); `claude/quirky-albattani-uads8u` เป็นสำเนาเดียวกัน
> ทดสอบมือถือรอบ 2 (หัวข้อ 10): ปุ่ม △✕□○ ของ Joystick เลือก/ลาก/ลบได้แล้ว, ปุ่มที่เพิ่มใหม่ไปวางที่ว่าง, เมนู Buttons แบบ Lavender ใช้ร่วมกันทุกโหมด (มีใน 4 BTN/8 BTN ด้วย), ปุ่ม Start/Stop เหลือแต่รูป, Settings เลือกโหมดแล้วกด Edit layout/Saved layouts ไปโหมดนั้นเลย
> รอบล่าสุด (หัวข้อ 11): หน้า LineSonic ทั้ง 3 หน้า (เมนู, PID Tuning, Read Sensor) เป็น Lavender Glass แล้ว — หัวหน้าเดียวกัน (ปุ่มแมว, ป้าย BLE ตัวกลางที่เปิด sheet), การ์ด Step แบบกระจก ปุ่ม 48px, เมนู ⋯, แถบปุ่มส่งคำสั่งติดด้านล่าง, Undo/ถามยืนยัน, ชื่อ "Junction hold", หน้า Sensor แบบช่องกระจก; คำสั่ง BLE ไม่เปลี่ยน
> test ผ่าน 346 ตัว และ `flutter analyze` ไม่เจอปัญหา
> **กฎจากเจ้าของ:** ห้ามแก้อะไรที่กระทบ Arduino Library (ดูหัวข้อ 0)

---

## 0. Start here (next session)

| Item | Value |
|---|---|
| Working branch | `claude/admiring-tesla-o410lj` (PR #2 head) = `claude/home-lavender-glass` + the commits from `ea4b98b` on, including the BLE status sheet commits (`aa0e05c` … `94038e1`). `claude/quirky-albattani-uads8u` is the same commits (the session that built the sheet pushed there first, then fast-forwarded PR #2 with the owner's OK). |
| Based on | `origin/release/2.1.0-android` (v2.1.1+21) |
| PR | **#2 open**: `claude/admiring-tesla-o410lj` → `release/2.1.0-android` (https://github.com/Amornthep-ra/app_contro/pull/2). Mergeable, no reviews yet, no CI in the repo. Pushing to the branch updates the PR. |
| `claude/home-lavender-glass` | older copy of the same work (stops at `7c83c16`); do not push new work there, it is not the PR head |
| `main` / `claude/clever-johnson-5fxeqr` | untouched (still 2.0.8 code; do not use). An earlier attempt built on `main` was discarded. |
| Tests | `flutter test` → 346 passing; `flutter analyze lib test` → no issues |
| Branches | **Use `claude/admiring-tesla-o410lj` only.** `claude/home-lavender-glass` is an old copy without the last 20+ commits; the owner once ran it by mistake and saw the old BLE sheet. |
| Flutter used | 3.47.9 stable (Dart 3.13.7); `pubspec.lock` needs Flutter ≥ 3.44 |

### Owner rules (must keep)
1. **Do not change anything the Arduino library depends on**: BLE packets/commands, button IDs and names, joystick axis directions (Y- is up, Y+ down), the △ ○ ✕ □ face buttons, and the CMD / DRV / TRN / X / Y telemetry text and numbers.
2. **Keep the backgrounds** `assets/BG_Portrait.png` (portrait pages) and `assets/BG.png` (control pages) unchanged. Restyle everything else to match them.
3. English-only UI (`LanguageController` is locked to English on this branch).

### Commits on the branch (oldest → newest)
| Commit | What |
|---|---|
| `9c500d1` | Home → Lavender Glass + ambient animated background |
| `3f25a4e` | Lavender native splash |
| `181728c` | Shared design system moved to `lib/core/ui/lavender_glass.dart` |
| `3e9b062` | BLE Connection page restyle + layout bug fixes |
| `d340293` | Shared 40 px `CatBackButton` (BLE + LineSonic) |
| `3651aab` | Controller phase 1 — Start/Stop prominence, locked-control look |
| `9f68f3d` | Controller phase 2 — toolbar: Back left, Settings right |
| `bab2601` | Controller phase 3 — speed panel / Settings / editor hint to glass |
| `a7c2aaf` | Controller phase 4 — veil over corner cats on short screens |
| `d4d9cf4` | Start/Stop moved into the toolbar next to Back; placement editing removed |
| `ea4b98b` | 4/8 BTN speed panels float under Speed instead of pushing the pad down |
| `23c28e5`, `a18fdb3`, `cf47bbf`, `9f439de` | Layout editor: full 48 px tool taps, square 24 dp grid aligned with snapping, 6 dp minimum control gap, tests |
| `38ab1bf`, `08d2696`, `a4818cb` | Handoff notes |
| `aa0e05c` | BLE status sheet moved verbatim to `lib/core/widgets/ble_connection_sheet.dart` (LF), no behaviour change |
| `b281f23` | Sheet header follows the badge; Scanning Ns + Stop; empty state; Close; fixed header/footer, 85% height in landscape |
| `a135011` | Robot rows shared with the BLE page (`ble_device_row.dart`); "Connect <name>"; spinner only on the tapped row |
| `798250e` | Diagnostics behind a footer button (option A) with Copy inside; Forget in a ⋯ menu with confirmation |
| `94038e1` | `test/ble_sheet_ui_test.dart` (17 tests, incl. 48 px targets) |
| `faaf5b4`, `f114011` | Handoff notes |
| `6d0444a` | Device test: Start/Stop no longer a Hero (it flew over the page transition when switching modes) |
| `69d98aa` | Device test: Start ring, Stop halo, glow and spinner centred on the artwork's round face |
| `c1333af` | Device test: one-row Pair Code dialog when the keyboard leaves < 300 px |
| `6ffc92d` | Device test: "Buttons" tool back in the Joystick layout editor |
| `57cdb74` | Handoff notes |
| `4c26dd4` | Device test 2: Joystick face buttons selectable in the editor (frame hit-tests its whole box) |
| `f9f6d80` | Device test 2: shared Lavender "Buttons" sheet (`gamepad_controls_sheet.dart`) for Joystick and 8 BTN |
| `1e2239e` | Device test 2: Buttons tool on 8 BTN and 4 BTN |
| `850c7e3` | Device test 2: added controls go to a free spot (`GamepadEditMetrics.freeSpotFor`); others pinned |
| `e459fed` | Device test 2: Start/Stop artwork only (no glow, halo, breathing ring) |
| `412c76b` | Device test 2: Settings' Edit layout / Saved layouts act on the chosen mode (`ControlModeSettingsResult`) |
| `a2d6d12` | Handoff notes |
| `bb27d8f` | LineSonic plan (section 11) |
| `d64a243` | LineSonic: shared header `LineSonicScaffold` on PID Tuning + Read Sensor |
| `17c5542` | LineSonic hub: shared badge, glass tiles (and the hub test in `widget_test.dart`) |
| `388ea4a` | PID: step card band fixed |
| `0a22c6d` | PID: glass step cards, mode colours, 48 px controls, ⋯ menu, "Junction hold" |
| `10bf97f` | PID: fixed bottom action bar, "Add Step" row, no FAB |
| `3727f6c` | PID: Undo for Delete step; confirm Load / Save over / Delete preset |
| `4f83540` | PID: glass preset row, Lavender picker sheet and Save dialog |
| `a11343e` | Read Sensor restyle; shared `linesonic_controls.dart` |
| `492d29d` | PID: Save preset dialog owns its text controller (was disposed during the closing animation) |
| `a7e25fa` | `test/linesonic_ui_test.dart` (15 tests) |

### Suggested next steps
1. **Owner re-test on the phone** of section 9 and the BLE status sheet (section 7), Android and iOS (the iOS sheet path uses `showCupertinoModalPopup`). The owner has a device checklist artifact (65 checks, copyable report).
2. Owner re-test of section 10 on the phone (Buttons sheet on all modes, selecting/moving Joystick buttons, Settings → other mode → Edit layout).
3. **Layout editor leftovers** the owner did not pick yet (section 6, "Layout editor — not done"): group the edit toolbar, 12 px top edge, even 4 BTN default spacing.
4. Real-device check (see "Not yet verified" in each section), especially blur/animation smoothness on low-end Android, iPhone landscape safe areas, the floating speed panels and dragging/snapping in the editor.
5. Owner re-test of the **LineSonic** pages on the phone (section 11, "Not yet verified").
6. Keep PR #2 moving: answer reviews, keep it mergeable. Do not merge without the owner.

### How the owner likes to work
Review first (render real sizes, measure, list findings with numbers) → written plan with recommended defaults and the decisions they need to make → implement only after "ตามที่แนะนำ" or explicit choices → one commit per fix, tests, before/after screenshots. Answers in Thai; code, commits and PR text in English.

---

## 1. How we worked (tooling notes)

### Flutter in the cloud container
```bash
mkdir -p /opt/flutter-sdk && cd /opt/flutter-sdk
curl -sSfL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.9-stable.tar.xz -o flutter.tar.xz
tar -xf flutter.tar.xz && rm flutter.tar.xz
git config --global --add safe.directory /opt/flutter-sdk/flutter
export PATH=/opt/flutter-sdk/flutter/bin:$PATH
```
- `flutter pub get` / `flutter analyze` rewrite `analysis_options.yaml` and bump SDK-pinned entries in `pubspec.lock`. **Revert both before committing**: `git checkout -- analysis_options.yaml pubspec.lock`.
- `flutter pub get` also leaves generated `linux/`, `macos/`, `windows/` folders behind (this release deleted those platforms in `13077ee`). Delete them; never commit them.

### Git / pushing
- The session can only push to its designated branch. Rewriting it (force push) is blocked by the permission system unless the owner explicitly types or approves the exact command.
- If your local branch has another name, push with `git push origin <local-branch>:claude/admiring-tesla-o410lj`, and make sure the local branch does **not** track `claude/home-lavender-glass` (a bare `git push` would land there).

### Line endings (important)
Many Dart files are **CRLF** (e.g. `home_page.dart`, `bluetooth_ble_page.dart`, the three control pages, `gamepad_app_bar.dart`); some are LF; `connection_status_badge.dart` and `ble_pairing_prompt_wiring_test.dart` are **mixed** (the badge's LF-only lines are in its pairing code). The BLE status sheet now lives in its own LF file, `ble_connection_sheet.dart`. For a pure-CRLF file, `sed -i 's/\r$//' f`, edit, then `sed -i 's/$/\r/' f` and check `git diff --stat` stays small. Preserve each file's endings or the diff explodes. Edit by normalising to LF, changing, then restoring CRLF; for mixed files patch at byte level. Only run `dart format` on files you touched (formatting a whole folder reformats unrelated files).

### Rendering screenshots without a device
Write a temporary widget test (e.g. `test/zz_preview_test.dart`, **never commit it**) that:
- loads real fonts with `FontLoader` (`assets/fonts/Roboto/static/*.ttf`, `assets/fonts/Kanit/*`, and Material icons from `/opt/flutter-sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`),
- sets `tester.view.physicalSize` / `devicePixelRatio` (phone portrait 1080×2400 @ 2.625; landscape 914×411 logical; small 640×360),
- pumps the page, `precacheImage`s every `Image` inside `tester.runAsync`, then captures a `RepaintBoundary` with `toImage` and writes a PNG.
- Use fixed `pump(Duration)` calls, not `pumpAndSettle`, when a spinner/pulse is running. Animated cross-fades need ~1 s of pumps after a state change or you capture the old frame.
- `AmbientMotion.enabledByDefault = true` in the harness to see pulses/motion (it is off under `flutter test`).

### Testing gotchas found
- The default test font is much wider than real fonts. Layout-fit tests (toolbar rows) must load Roboto (see `test/control_start_stop_test.dart`).
- A `Completer` created in `setUp` completes outside the fake-async zone; create it inside the test body.
- **Precache images before measuring or tapping controls.** Pad buttons size themselves from their images; until decoded under `flutter_test` they are 0×0, so they are not hit-testable and rects are wrong. (This was the cause of the old "8 BTN edit-mode items are not hit-testable" note; it is not an app bug.) `test/gamepad_edit_layout_test.dart` shows the `runAsync(() => precacheImage(...))` pattern.
- Taps that call `gamepadBuzz()` need a mock for the `vibration` method channel, or the test fails with `MissingPluginException`.
- Opening the layout editor in a test: tap the `Settings` tooltip, then the `Edit layout` text.
- The BLE status sheet can be rendered with a fake `BleConnectionCoordinator` (`enableBlePlatformBindings: false`, `debugEmitForTesting(state)`) and an injected badge `presentationState`, see `test/ble_sheet_ui_test.dart`. It has busy spinners while scanning/connecting, so step with `pump(Duration)` instead of `pumpAndSettle`. With `securityState: pairingRequired` and connected, the sheet closes itself for the automatic pairing prompt unless `coordinator.markPairingPromptPresented()` was called first.
- `ButtonStyle.textStyle` replaces the theme's text style (font family included); give label `Text`s their own size/weight instead, or they fall back to the platform font (boxes under `flutter_test`).
- A `ListTile` with `tileColor` paints on the nearest `Material`; inside a scroll view, give the scrolled content its own `Material(type: transparency)` or the colours paint outside the viewport.

---

## 2. Design system — "Lavender Glass"

- `lib/core/ui/lavender_glass.dart`
  - `LavenderPalette`: background `#F3EEFF`, ink `#261B39` (+ soft/muted alphas), violet `#7256B6`, violetBright `#8B6CF2`, cyan `#37D8FF`, success `#1FBF95`, warning `#F2A33A`, coral `#F05264`; `brandGradient` violet→cyan; display font `Kanit` (Regular/Bold registered in `pubspec.yaml`, titles only).
  - `GlassPanel` (backdrop blur, white glass, light rim; shadow drawn only outside the rounded shape), `GradientActionButton` / `GlassActionButton` (with `busy` spinner, `accent`), `LavenderChip`, `showLavenderConfirmDialog`, `FrostedBarBackground` (frosted app-bar strip shown when content scrolls under it).
- `lib/core/ui/ambient_motion.dart` — `AmbientMotion.enabledFor(context)`: decorative loops are off under `flutter test` and when the OS "remove animations" setting is on.
- `lib/features/bluetooth/widgets/`: `ble_device_row.dart` (`BleDeviceRow`, `BleRoundIcon`, `bleScanResultName`, `sortBleScanResults`) and `ble_connection_status.dart` (`BleSecurityLine`, `resolveBleConnectedDeviceName`), shared by the BLE page and the status sheet. `bluetooth_ble_page.dart` re-exports the helpers its tests import.
- `lib/core/widgets/`: `ble_connection_sheet.dart` (`BleConnectionSheet`), `ble_status_orb.dart`, `signal_bars.dart`, `cat_back_button.dart` (40 px `Back.png` in a 48 px target; `leadingWidthFor(padding)` aligns it with content), `control_background.dart`, `control_start_stop.dart`, `gamepad_edit_hint.dart`.

---

## 3. Splash — DONE

- `flutter_native_splash` background `#EDE3F6` (sampled from `BG_Portrait.png`) for Android, Android 12 and iOS; no `*_dark` keys; `web: false`.
- `assets/Logo/splash_logo.png`: "PB CONTROLLER" wordmark recoloured to deep violet `#4A308C` without the cyan glow (unreadable on lavender). D-pad unchanged. `splash_android12.png` (D-pad only) unchanged.
- Regenerate: `dart run flutter_native_splash:create`, then `git checkout -- ios/Runner/Info.plist` (plugin only rewrites indentation/line endings).
- Older gotchas: `remove` leaves `drawable-night*/launch_background.xml` without a logo — delete `drawable-night/` and `drawable-night-v21/` after `create`. Don't quantise PNGs with PIL (bands the glow); use `pngquant`.

Not yet verified on a real device: Android ≤11, Android 12+, iOS.

---

## 4. Home (`lib/features/home/home_page.dart`) — DONE

- `widgets/home_backdrop.dart` — `HomeBackdrop`: untouched `BG_Portrait.png` + optional ambient motion (drifting aurora light, twinkles on the painted sparkles, breathing glow on collar / paw sign / cat-house door, floating motes). ~30 fps timer; pauses when Home is covered, when the app is backgrounded, and with reduce-motion. `HomePage(animateBackground: false)` disables it.
- Header: logo badge + Kanit title + "Robot remote by PrinceBot"; frosted strip when scrolled.
- BLE hero card: status orb, hint text, **Reconnect** + **Scan devices** when a last device exists, device name + signal + Manage when connected. The old "No recent device yet" card is merged into it.
- Controller / LineSonic glass tiles with subtitles; Contact + Arduino Library grouped into a "Resources" list; version line `PB Controller · vX`; content max width 560; pull-to-refresh (which opened the BLE page) removed; dead `isDark`/`isThai` code removed.
- Tests: `test/home_backdrop_test.dart` (motion pauses when covered / backgrounded / reduce-motion).

---

## 5. BLE Connection (`lib/features/bluetooth/bluetooth_ble_page.dart`) — DONE

- Fixed: status text centred away from its icon; empty device panel stretching to the bottom; "Last device" Connect active while already connected; "Tap scan to begin" shown while scanning.
- Status card with the shared orb; full-width **Scan devices**; countdown + **Stop** while scanning; when connected: security state in words, **Pair code** or a "Paired" chip, **Disconnect**.
- Coral only for real problems. Robots sorted by signal level then name, signal bars, "Last used" chip, spinner on the row being connected. "Forget device" in a ⋯ menu with a glass confirmation. Glass "Bluetooth is off" dialog. Coordinator logic unchanged.
- Tests: `test/ble_page_ui_test.dart`; `ble_pairing_prompt_wiring_test.dart` paired case checks "Paired" is a label.

---

## 6. Controller pages (4 BTN / 8 BTN / Joystick) — DONE

Files: `lib/features/gamepad/gamepad_4_button_page.dart`, `gamepad_mode_edit.dart` (8 BTN), `lib/features/joystick/joystick/presentation/joystick.dart`, `control_mode_settings_page.dart`, shared widgets in `lib/core/widgets/`.

### Toolbar
```
[Back] [Start/Stop]   Speed · CMD/telemetry · BLE   [Settings]
```
- `GamepadControlLayout.measure(context, labels, leadingCount: 2)` + `GamepadControlRows`: Back and Start/Stop are pinned left (16 px safety gaps), Settings pinned right, the rest centred. Rows still wrap at large text.
- Start/Stop (`ControlStartStopButton`) is 48 px like Back/Settings. Next to Back on purpose: Back also stops control before leaving; Settings does not. Stop has a red halo; Start has a breathing green ring while control is off.
- "Tap Start to drive" (`ControlStartHint`) sits just under the toolbar pointing at Start — only when the toolbar is a single row and (on 4/8 BTN) the speed panel is closed.
- **Start/Stop placement editing was removed** (owner request): no `EditableStartStopSurface` / `StartStopPlacement` / `StartStopObstacle` any more. Old saved `*_start_stop` prefs and the `startStop` key in presets are ignored; reset still removes the old pref.
- Compact Bluetooth wording: only when the toolbar would otherwise wrap, the BLE badge uses `BlePresentationState.shortLabel` ("Checking…", "Unavailable", "Needs permission", "Turning on…", "Turning off…"); screen readers keep the full label. Result: Joystick stays on one row at 640×360. 8 BTN still wraps at 640 (its CMD text is long — pre-existing).

### Pad
- `ControlInputGate`: locked controls (before Start / while suspended) are desaturated at 0.72 opacity; tapping them shows the "Tap Start to drive" notice; control state is kept across lock/unlock.
- `ControlBackground`: same `BG.png`; on screens shorter than 400 px a soft lavender veil fades the bottom-corner cats (full at 340 px). Control positions untouched.

### Chrome
- 8 BTN speed panel: light glass; DRV / TRN labels kept, small "Drive" / "Turn" captions added. 4 BTN Lo/Med/Hi menu unchanged.
- Both speed panels float over the pad (`GamepadToolbarDropdown`, left edge under the Speed slot via `GamepadControlLayout.slotLeft`, kept on screen), so opening them never moves or resizes the drive buttons. Trade-off: while open, the 8 BTN panel covers the top of ↑ / △ (fully at 640×360, where the toolbar wraps).
- Settings page: violet selection instead of pink.
- Layout editor: `GamepadEditHint` under the edit toolbar ("Tap a control to select it · Long-press a tool to see its name" → "Drag to move · − / + to resize · Done when finished"). Edit toolbar icons/tooltips unchanged.
- Layout editor spacing: each edit tool takes taps over its whole 48 px slot; the grid is a square `GamepadEditMetrics.gridStep` (24 dp) drawn by `GamepadEditGrid` over exactly the box controls snap in (`snapToGrid`, from the pad's top-left); `GamepadEditMetrics.crowdsNeighbour` keeps `minControlGap` (6 dp) between touch areas but always lets already-closer controls move apart (the Joystick's default face buttons are ~1 dp apart). Tests: `test/gamepad_edit_layout_test.dart`.

### Layout editor — not done (owner has not picked these yet)
- Group the edit toolbar: [Done] | [Lock − +] | [Grid] | [Undo Redo] | [Reset Delete], 8 px inside a group, 16 px between groups (needs a group-gap option in `GamepadCenteredToolbar` / `GamepadToolbarLayout.calculate`). Reset sits next to Redo today and wipes the layout without asking (Undo can bring it back). Optional "Done" text label.
- Top edge: `GamepadEditMetrics.safeTopEdgePad` is 4 px vs 12 px on the other edges, so controls can sit right under the toolbar/hint (and, while driving, under the floating speed panel). Proposed: 12 px, clamp saved layouts on load for 4/8 BTN.
- 4 BTN default spacing is uneven (914×411: ↑↓ 15 px apart vs ←→ 30 px; 640×360: 22.5 vs 13.6).
- Unused file noticed: `lib/features/gamepad/controllers/gamepad_edit_controller.dart` (no imports).

### Tests
`test/control_start_stop_test.dart`, `test/control_chrome_test.dart`, `test/control_input_gate_test.dart`, `test/gamepad_control_toolbar_test.dart` (edges + safety gap), `test/control_speed_panel_test.dart` (floating speed panels, `slotLeft`), `test/gamepad_edit_layout_test.dart` (editor tool taps, grid/snap, 6 dp gap), plus the existing toolbar/joystick/review tests.

### Not changed on purpose (Arduino library)
Joystick axes and Y-/Y+ labels, △○✕□ face buttons, packets, button IDs, CMD/DRV/TRN/X/Y telemetry text.

### Not yet verified on a real device
Start/Stop from the toolbar while driving (thumb reach in landscape), pulse smoothness on low-end Android, iPhone landscape safe areas, layouts users saved in older versions.

---

## 7. BLE status sheet (`lib/core/widgets/ble_connection_sheet.dart`) — DONE

The sheet that opens from the Bluetooth badge (controller pages and LineSonic). Owner answered "ตามที่แนะนำ": all plan items, diagnostics option A. Rendered at 914×411 and 411×914 before and after.

### Findings (before) → what changed
1. "No devices found" while still scanning → "Looking for robots…" while scanning, "No robots found yet" after, with the BLE page's hints.
2. Header "Not connected" while the badge said "Scanning…" → the badge passes its `presentationState`; `resolveBleSheetPresentation` uses it, and the sheet's own scan/connect state only fills in while the badge is idle. Same status orb, title + hint; when connected: robot name + `BleSecurityLine`.
3. Disabled "Scanning..." pill, no way to stop → "Scanning Ns" (busy) + **Stop** (`coordinator.stopScan()`).
4. Cancel/diagnostics below the fold → "Close"; header and footer fixed, only the middle scrolls; max height 85% in landscape, 60% in portrait, capped to the safe area.
5. MAC as the name, raw RSSI, unsorted, no "Last used", spinner on every row → shared `BleDeviceRow` / `sortBleScanResults` / `bleScanResultName`; spinner only on the tapped row (`_connectingDeviceId`), the others locked.
6. "Connect last" → "Connect <name>" (scan list name, else the remembered name, else "Connect last robot"). On narrow sheets it takes the spare width and Scan shortens to "Scan".
7. Diagnostics row for everyone with a hidden copy button → option A: "Diagnostics" text button at the left of the footer; opens the panel at the top of the list (scrolled into view) with **Copy** inside, which says "Copied" for 2 s (a snack bar would sit behind the sheet's barrier). Same fields.
8. Forget next to Cancel with no confirmation → "Forget device" in a ⋯ menu next to Close, `showLavenderConfirmDialog` like the BLE page.
9. 30 px buttons → every control is ≥ 48 px (Lavender 48 px buttons, 48 px text-button minimum, Material 48 px icon targets, rows ≥ 64 px). This landed with the restyled buttons in `b281f23`/`798250e`; `test/ble_sheet_ui_test.dart` measures it in both orientations.

### Layout
```
[orb] Title / hint                 [actions]     ← wide (landscape)
───────────────────────────────────────────────
(diagnostics panel when open)
robot rows / empty state           ← only this scrolls
───────────────────────────────────────────────
[Diagnostics]                [⋯] [Close]
```
On narrow sheets (portrait, large text) the actions move under the title.

### Notes
- Pair code stays a 48 px icon button with tooltip "Pair code"/"Paired" (existing pairing tests rely on it).
- The status orb only spins when `AmbientMotion.enabledFor(context)` (off under `flutter test`, and with reduce-motion).
- The sheet's barrier is still `Colors.black87` and the iOS path still uses `showCupertinoModalPopup`; unchanged.
- No coordinator/connection logic changed (Arduino rule safe).

### Not yet verified on a real device
Opening the sheet from all three controller pages and LineSonic; Stop during a real scan; the iOS sheet (safe areas, height); "Copied" + clipboard on device; the Forget dialog over the sheet.

## 8. Open questions for the owner
- △○✕□ face buttons resemble PlayStation symbols — possible trademark question for a store release; left unchanged because the Arduino library uses them.
- Joystick Y- is "up" (matches the packets); clearer forward/back labelling would need coordination with the library examples.
- 8 BTN toolbar wraps to two rows on 640 px screens because of its long CMD text; shortening it would change telemetry text (library rule), so it was left.

---

## 9. Device-test fixes (owner's phone, after PR #2) — DONE

The owner ran PR #2 on an Android phone (about 800×360 logical in landscape) and reported four things. All four were reviewed, planned and approved ("ตามคำแนะนำ"), one commit each.

1. **Start/Stop stayed on screen while switching modes** (`6d0444a`). `GamepadStartStopControlButton` wrapped itself in a `Hero` with the same tag on 4 BTN, 8 BTN and Joystick, so `pushReplacement` between modes flew it above the transition. The Hero and the `heroTag` parameter are gone; `test/control_start_stop_test.dart` checks there is no Hero around it on all three pages.
2. **Highlight ring off-centre** (`69d98aa`). The round face of `control_start.png` / `control_stop.png` is centred at 54.1% / 55.1% of the image height (cat ears on top), diameter 87% / 90%. `GamepadStartStopControlButton.faceOffset` / `faceDiameter` hold that; halo, glow and spinner are translated onto the face, and the Start ring is a painter from the face rim outwards (x1.0 → x1.32) that never changes the button's 48 px size (the old `Stack` ring could grow it to ~58 px).
3. **Pair Code dialog with the keyboard up** (`c1333af`). App layout, not a phone setting: the `AlertDialog` pinned Cancel/Pair, so a landscape keyboard left only those (800×360 with a 240 px keyboard also overflowed 4 px). Below 300 px of usable height (`LayoutBuilder` box minus reported keyboard/safe-area insets) it is one row `[field | Cancel | Pair]`; the field's label is the title, helper and 0/16 counter are hidden, errors still show. The `TextField` keeps its state across layouts (`GlobalKey` + owned `FocusNode`) so focus and the keyboard survive the switch. Tests in `test/pairing_code_dialog_test.dart`.
4. **Joystick page has CMD but no buttons** (`6ffc92d`). Not disabled: Joystick starts with two joysticks and △ ✕ □ ○ are added from the "Buttons" menu. The 2.1.0 single-row edit toolbar (`13077ee`) had dropped the menu's entry, so it could not be opened (already broken in released 2.1.x). A "Buttons" tool (gamepad icon) is back right after Done; 10 tools still fit one row at 640×360. Owner chose to **keep the default** (left + right joystick). Tests in `test/gamepad_edit_layout_test.dart` and `test/gamepad_toolbar_responsive_test.dart`.

### Follow-ups from this section
Both done in section 10 (shared sheet with a pinned Done; free-spot placement).

### Not yet verified on a real device
All four fixes above (the owner is re-testing).

---

## 10. Device-test fixes, round 2 — DONE

The owner confirmed section 9's items 1–3 and reported six more points; all reviewed, planned and approved ("ตามที่แนะนำ"), one commit each.

1. **Joystick face buttons could not be selected** (`4c26dd4`). `GamepadEditableButtonFrame` (used only by the Joystick page) hit-tested with the default deferToChild, and the page wraps the button in `IgnorePointer`, so nothing in the frame took taps; taps went to the right joystick underneath. Broken since 2.1.0 (`13077ee` replaced the frame's bordered box with `GamepadEditSelectionVisual`). Fix: `HitTestBehavior.opaque`.
2. **Shared Lavender "Buttons" sheet** (`f9f6d80`): `features/gamepad/widgets/gamepad_controls_sheet.dart` (`showGamepadControlsSheet`, groups of `GamepadControlChoice` with artwork or icon). Pinned header + 48 px Done, tap outside closes, ticks apply at once (Undo reverts), tiles ≥ 56 px, two columns when ≥ 440 px wide. Replaced the old green (Joystick) and pink (8 BTN) sheets.
3. **Buttons tool on 8 BTN and 4 BTN** (`1e2239e`). 8 BTN lost its entry in 2.1.0 like Joystick; 4 BTN's menu (2.0.8) was gone entirely. Groups: 8 BTN "Left pad"/"Right pad", 4 BTN "Arrows". Edit toolbars now count 10 tools (one row at 640×360, text scale 2).
4. **Free-spot placement** (`850c7e3`). `GamepadEditMetrics.freeSpotFor` (default spot if it keeps 6 dp, else nearest 24 dp grid point in the safe area). Before adding, controls already on the pad are pinned in `_layout` / `_layoutAll` (defaults depend on the active set). 4 BTN's duplicated specs became `_fourButtonSpecs()`. Note: with several buttons added to the two-joystick pad, the nearest free spots can be scattered (e.g. ○ near the right edge); the owner can arrange them.
5. **Start/Stop artwork only** (`e459fed`): no glow, red halo or breathing ring (cut off by ears/paw/tail). Spinner still centred on the face (`faceOffset`). "Tap Start to drive" still shows.
6. **Settings mode switching** (`412c76b`). Edit layout used to edit the mode Settings came from. Now `controlModeSettingsRoute` returns `ControlModeSettingsResult(mode, open:)`; pages switch (same BLE hand-off) with `ControlPageArguments(open:)`, `AppRoutes` passes `openOnArrival`, and the new page opens its editor / saved layouts after its layout loads. Same-mode Saved layouts still opens over Settings. Section title "Layout · <mode>".

Tests: `test/gamepad_controls_sheet_test.dart`, `test/control_mode_switch_test.dart` (through `AppRoutes`), and additions in `test/gamepad_edit_layout_test.dart`, `test/control_start_stop_test.dart`, `test/widget_test.dart`, `test/gamepad_toolbar_responsive_test.dart`. The selection, placement and mode-switch tests fail on the previous code.

### Not yet verified on a real device
Everything in this section.

---

## 11. LineSonic pages — plan (owner approved "ตามที่แนะนำ", 2026-11-03)

Files: `lib/features/linesonic/linesonic_page.dart` (hub, LF), `linesonic_pid_page.dart` (CRLF), `linesonic_sensor_page.dart` (CRLF). The app is portrait-only, so these were rendered at 411×914 and 360×640, text scale 1.0 and 1.3, before any change.

### Findings (before)
Hub
1. Own "BLE Off" pill (32 px tall) that opens the full BLE page, while PID / Sensor use the shared badge that opens the BLE status sheet; the two disagree ("BLE Off" vs "Checking Bluetooth…").
2. Cards use a private palette instead of `GlassPanel` like Home.

PID Tuning
3. Bug: each step card's `Material(color: toneBg)` wraps the card's margin, so a pale band runs edge to edge behind every card (16 px wider than the card on both sides).
4. Bug: transparent header; scrolled content runs under the "PID Tuning" title.
5. Bug: the "Add Step" FAB covers fields (Straight at 360×640, SUM threshold with the keyboard up).
6. Title cut to "PID …" at 360 px / text 1.3 (wide badge).
7. Targets under 48 px: step header icons and Save/Load preset 40×40, speed chips 37×28, segmented buttons 32 tall, switches scaled to 0.65 (≈39×26), number fields 36 tall, SW1 / Reset 40 tall.
8. Text 10–11 px (chips, segments, field labels, step pill).
9. Off-palette colours: Send All #2563EB, PD+Speed green, SW1 teal, Time step blue, CheckSum step orange.
10. No confirmation or undo for Delete step, Load preset (replaces all steps), Save over a preset, Delete preset.
11. Off / All Black / All White has no label.
12. Preset picker sheet and Save dialog are stock Material.

Read Sensor
13. Stock Material buttons and dropdown.
14. Same header issues as 4 and 6.
15. Plain chevron Back on PID and Sensor; hub and BLE page use the cat Back.

### Decisions (owner)
1. Hub badge: the shared `ConnectionStatusBadge` (opens the BLE status sheet).
2. Step colours: Time = violet, CheckSum = cyan, no mode = muted.
3. Step header: ↑ / ↓ visible; Duplicate and Delete in a ⋯ menu.
4. Actions: a fixed glass bar at the bottom (Send All, Send PD+Speed, SW1, Reset board); "Add step" becomes a row at the end of the list (no FAB).
5. Delete step → snack bar with Undo; Load preset over steps, Save over a saved preset and Delete preset → `showLavenderConfirmDialog`.
6. Off / All Black / All White is labelled "Junction hold".
7. Sensor "Read (force)" moves into the Log section.

### Phases (one commit per item)
1. Shared header for the three pages: cat Back, Kanit title that scales down instead of truncating, frosted strip when scrolled, BLE badge in the controller-toolbar pill style with short labels.
2. Hub: shared badge, `GlassPanel` cards.
3. PID: band bug; glass step cards + colours; 48 px targets, ≥ 12 px text, full-size switches, ⋯ menu; bottom action bar + Add step row; Undo / confirmations; Lavender preset sheet and Save dialog; "Junction hold".
4. Sensor: Lavender buttons and interval chips, value tiles, Log panel with Read (force) and Clear.
5. Tests, before/after renders, notes.

### Must not change (Arduino library)
`SEQ=` (field order `mode,value,kp,kd,speed,afterMs,afterSpeed,stopMs,lineColor,holdMs,holdThreshold,holdMode`), `SEQPD=`, `SW1=1`, `RESET=1`, `SENS=1`, the `SENS=…,SUM=` parsing, KP / KD / Speed / S1… / SUM wording, the 3 s / 1 s / 200 ms send limits, and the saved keys `linesonic_steps_v2` / `linesonic_presets_v1`.

### Result — DONE (all phases)
- `widgets/linesonic_scaffold.dart` (LF): `LineSonicScaffold` (cat Back, Kanit title in a `FittedBox` so it scales instead of being cut, `FrostedBarBackground` when scrolled, optional `bottomBar` hidden while the keyboard is up, `contentTop(context)` for list padding) and `LineSonicBleBadge` (the shared `ConnectionStatusBadge` inside a one-item `GamepadControlScope` with `compactBle: true`, so it draws the controller toolbar pill with short labels and opens the BLE status sheet).
- `widgets/linesonic_controls.dart` (LF): `LineSonicSegments<T>` (glass segmented control, 42 px segments in a 48 px rim) and `LineSonicCaption`.
- Hub (`linesonic_page.dart`, LF): `blePageBuilder` and the private pill are gone; two `GlassPanel` tiles (cyan PID, mint Sensor).
- PID (`linesonic_pid_page.dart`, CRLF): `_buildStepCard` + `_StepTone` (Time violet, CheckSum cyan, none muted), `_StepIconButton` (48 px), ⋯ `PopupMenuButton` (Duplicate / Delete), `_PresetChips` (48 px targets around 34 px pills), `_SwitchRow` (full switch, 48 px row), `_DisabledWhen`, `_NumberField` (48 px, glass fill). Tapping the selected mode still shows / hides its options; the chevron next to "Mode" does the same. `_buildActionBar` (Send PD+Speed, Send All gradient, SW1 cyan, Reset Board coral). Deleted steps wait in `_pendingDeleted` until the Undo snack bar closes. `_PresetNameDialog` owns its controller. Drag-to-reorder never had drag handles (only ↑ / ↓ work); unchanged.
- Sensor (`linesonic_sensor_page.dart`, CRLF): glass controls panel, interval as segments, value tiles (columns = width / 84, 3–8), SUM row, log panel with Read (force) + Clear and selectable text. `debugReceivedLines` (visibleForTesting) feeds lines through `_handleData`.
- Checked: `_buildSeqPayload`, `_buildSeqPdPayload`, `_sendCommand`, `_sendSW1`, `_sendReset`, `_sendSequence(Pd)`, `_StepData.toJson`, `_parseLine`, `_sendRead`, `_forceReadTx`, `_setAuto`, `_handleData`, `_addLog` are byte-identical to `a2d6d12`; nothing under `lib/core` changed.
- Thai strings in the rewritten parts were dropped (English-only rule; they were identical to the English ones anyway). Labels kept: "Send All", "Send PD+Speed", "SW1", "Reset Board", "Add Step", "Read Now", "Auto On/Off", "Read (force)".

### Testing notes
- `test/linesonic_ui_test.dart` (15). The hub test in `widget_test.dart` now checks the shared badge instead of opening the BLE page.
- Rendering: one big `tester.drag` (e.g. −3000 px) on the PID list lands past the lazily estimated extent and shows an empty viewport; drag in ~400 px steps with pumps. `FrostedBarBackground` may not show in captures taken right after a large jump.
- The log uses `fontFamily: 'monospace'`, which is not loaded under `flutter_test` (boxes in renders).

### Not yet verified on a real device
The three pages on Android and iOS: the badge pill and BLE sheet from LineSonic, the frosted header while scrolling, the bottom bar with the keyboard (it hides) and on iPhone home-indicator insets, blur cost of one `GlassPanel` per step on low-end Android with many steps, the ⋯ menu, Undo snack bar over the bottom bar, the Save preset dialog above the keyboard.
