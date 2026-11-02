# UI Handoff — PB Controller (updated 2026-11-02)

> **สรุปสั้น (ไทย):** ปรับ UI ทั้งแอปเป็นธีม "Lavender Glass" แล้ว 4 ส่วน คือ Splash, หน้า Home, หน้า BLE Connection และหน้า Controller (4 BTN / 8 BTN / Joystick)
> รอบล่าสุดเพิ่ม: แผงความเร็ว 4/8 BTN ลอยใต้ปุ่ม Speed (ไม่ดัน pad), หน้า Edit layout (ปุ่มเครื่องมือกดได้เต็ม 48px, กริดจัตุรัส 24dp ตรงจุด snap, ปุ่มห่างกันอย่างน้อย 6dp)
> งานทั้งหมดอยู่ที่ branch `claude/admiring-tesla-o410lj` ซึ่งเปิดเป็น **PR #2 → `release/2.1.0-android`** แล้ว (ยังไม่มี review, repo ไม่มี CI)
> test ผ่าน 288 ตัว และ `flutter analyze` ไม่เจอปัญหา ทั้งหมดยังไม่ได้ทดสอบบนมือถือจริง
> **งานถัดไปที่รอคำตอบเจ้าของ:** แผน BLE status sheet (หัวข้อ 7) — รีวิวแล้ว เขียนแผนแล้ว ยังไม่ได้แก้โค้ด
> **กฎจากเจ้าของ:** ห้ามแก้อะไรที่กระทบ Arduino Library (ดูหัวข้อ 0)

---

## 0. Start here (next session)

| Item | Value |
|---|---|
| Working branch | `claude/admiring-tesla-o410lj` (pushed, up to date) = `claude/home-lavender-glass` + the commits from `ea4b98b` on |
| Based on | `origin/release/2.1.0-android` (v2.1.1+21) |
| PR | **#2 open**: `claude/admiring-tesla-o410lj` → `release/2.1.0-android` (https://github.com/Amornthep-ra/app_contro/pull/2). Mergeable, no reviews yet, no CI in the repo. Pushing to the branch updates the PR. |
| `claude/home-lavender-glass` | older copy of the same work (stops at `7c83c16`); do not push new work there, it is not the PR head |
| `main` / `claude/clever-johnson-5fxeqr` | untouched (still 2.0.8 code; do not use). An earlier attempt built on `main` was discarded. |
| Tests | `flutter test` → 288 passing; `flutter analyze lib test` → no issues |
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
| `38ab1bf`, `08d2696` + this update | Handoff notes |

### Suggested next steps
1. **BLE status sheet** (section 7): reviewed and planned, waiting for the owner's answers (diagnostics option A/B, scope, OK to add to PR #2). The owner's usual reply "ตามที่แนะนำ" means: all commits, diagnostics option A, push to PR #2.
2. **Layout editor leftovers** the owner did not pick yet (section 6, "Layout editor — not done"): group the edit toolbar, 12 px top edge, even 4 BTN default spacing.
3. Real-device check (see "Not yet verified" in each section), especially blur/animation smoothness on low-end Android, iPhone landscape safe areas, the floating speed panels and dragging/snapping in the editor.
4. Review the **LineSonic** pages (`lib/features/linesonic/linesonic_page.dart`, `linesonic_pid_page.dart`, `linesonic_sensor_page.dart`) the same way: render → review → plan → implement in phases.
5. Keep PR #2 moving: answer reviews, keep it mergeable. Do not merge without the owner.

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
Many Dart files are **CRLF** (e.g. `home_page.dart`, `bluetooth_ble_page.dart`, the three control pages, `gamepad_app_bar.dart`); some are LF; `connection_status_badge.dart` and `ble_pairing_prompt_wiring_test.dart` are **mixed**. Preserve each file's endings or the diff explodes. Edit by normalising to LF, changing, then restoring CRLF; for mixed files patch at byte level. Only run `dart format` on files you touched (formatting a whole folder reformats unrelated files).

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
- The BLE status sheet can be rendered with a fake `BleConnectionCoordinator` (`enableBlePlatformBindings: false`, `debugEmitForTesting(state)`), see `test/ble_pairing_prompt_wiring_test.dart`; fake `ScanResult`s as in `test/ble_page_ui_test.dart`.

---

## 2. Design system — "Lavender Glass"

- `lib/core/ui/lavender_glass.dart`
  - `LavenderPalette`: background `#F3EEFF`, ink `#261B39` (+ soft/muted alphas), violet `#7256B6`, violetBright `#8B6CF2`, cyan `#37D8FF`, success `#1FBF95`, warning `#F2A33A`, coral `#F05264`; `brandGradient` violet→cyan; display font `Kanit` (Regular/Bold registered in `pubspec.yaml`, titles only).
  - `GlassPanel` (backdrop blur, white glass, light rim; shadow drawn only outside the rounded shape), `GradientActionButton` / `GlassActionButton` (with `busy` spinner, `accent`), `LavenderChip`, `showLavenderConfirmDialog`, `FrostedBarBackground` (frosted app-bar strip shown when content scrolls under it).
- `lib/core/ui/ambient_motion.dart` — `AmbientMotion.enabledFor(context)`: decorative loops are off under `flutter test` and when the OS "remove animations" setting is on.
- `lib/core/widgets/`: `ble_status_orb.dart`, `signal_bars.dart`, `cat_back_button.dart` (40 px `Back.png` in a 48 px target; `leadingWidthFor(padding)` aligns it with content), `control_background.dart`, `control_start_stop.dart`, `gamepad_edit_hint.dart`.

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

## 7. BLE status sheet — REVIEWED, PLAN WAITING FOR THE OWNER (no code changed)

The sheet that opens from the Bluetooth badge (`_ConnectionSheet` in `lib/core/widgets/connection_status_badge.dart`, used by the controller pages and LineSonic). It was not restyled with the BLE Connection page, so it lags behind it. Rendered at 914×411 with a fake coordinator.

### Findings
1. Shows "No devices found" while still scanning (`devices.isEmpty` ignores `_scanning`). The owner's device screenshot shows exactly this.
2. Header says "Not connected" with a crossed-out Bluetooth icon while the toolbar badge says "Scanning…" (amber).
3. The "Scanning..." pill is a disabled button that still looks tappable; there is no way to stop a scan.
4. "Cancel" only closes the sheet. With 3 robots, Cancel/Forget and diagnostics fall below the fold (viewport y 138–385, Cancel at y 467): max height is 60% of the screen.
5. Rows use `platformName` only (no `advName` fallback → MAC shown as the name, MAC repeated in the subtitle), raw "RSSI -52 dBm", unsorted, no "Last used", spinner on every row while connecting.
6. "Connect last" does not name the robot (`lastDeviceName` is available).
7. "BLE diagnostics" is a full-width row for everyone; its leading icon is a copy button (tap left = copy, tap elsewhere = expand). Diagnostics exist only in this sheet.
8. "Forget" sits next to Cancel with no confirmation (the BLE page uses a ⋯ menu + confirmation).
9. Buttons are 30–31 px tall (`minimumSize: Size(0, 30)`, `shrinkWrap`).

### Plan (one commit each)
1. Status and close: header from `resolveBlePresentationState` (same as the badge); empty state copies the BLE page ("Looking for robots…" / "No robots found yet" + hints); "Scanning Ns" + **Stop** (`coordinator.stopScan()`); "Cancel" → "Close"; header and footer fixed, only the list scrolls; max height 85% in landscape (60% portrait).
2. Rows: move `_DeviceRow`, `bleScanResultName`, `sortBleScanResults` from `bluetooth_ble_page.dart` to `lib/features/bluetooth/widgets/ble_device_row.dart` and use them in both places; track the connecting row; "Connect <lastDeviceName>".
3. Diagnostics (recommended option A: small "Diagnostics" text button in the footer that expands; "Copy" inside the panel; option B: move to Settings) and Forget into a ⋯ menu with `showLavenderConfirmDialog`.
4. 48 px tap targets for the sheet buttons.
5. Tests in `test/ble_sheet_ui_test.dart` (states, Stop calls `stopScan`, Close visible with 5 robots at 914×411, sorting/Last used/spinner, Forget confirmation, diagnostics collapsed, 48 px), plus the existing BLE page tests after moving `_DeviceRow`; before/after screenshots at 914×411 and 411×914.

Notes: `connection_status_badge.dart` has mixed line endings, so patch it at byte level. No coordinator/connection logic changes (Arduino rule safe).

---

## 8. Open questions for the owner
- △○✕□ face buttons resemble PlayStation symbols — possible trademark question for a store release; left unchanged because the Arduino library uses them.
- Joystick Y- is "up" (matches the packets); clearer forward/back labelling would need coordination with the library examples.
- 8 BTN toolbar wraps to two rows on 640 px screens because of its long CMD text; shortening it would change telemetry text (library rule), so it was left.
