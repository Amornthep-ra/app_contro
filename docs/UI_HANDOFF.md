# UI Handoff — Splash & Home (2026-11-02)

Branch: `release/2.1.0-android`

## 1. Splash Screen — DONE

- Source images:
  - `assets/Logo/splash_logo.png` — 1152×1152, transparent, D-pad + "PB CONTROLLER" (iOS + Android ≤11, shown at 288dp/pt)
  - `assets/Logo/splash_android12.png` — 1152×1152, transparent, D-pad + PB only, fits inside the 768px Android 12 mask circle
- Old `assets/Logo/Splash_Screen.png` removed (had a Gemini ✦ watermark, full-bleed square, 3.6 MB).
- `pubspec.yaml` → `flutter_native_splash`: background `#EDE3F6` (lavender, sampled from `BG_Portrait.png` so launch → Home has no colour jump), no `*_dark` keys (dark = light), `web: false`.
- `splash_logo.png` text "PB CONTROLLER" recoloured to deep violet `#4A308C` without the cyan glow (the glow was unreadable on lavender). D-pad unchanged. The Android 12 icon (`splash_android12.png`) is D-pad only and was not changed.
- Regenerated with `dart run flutter_native_splash:remove` + `create`.
- Splash PNG size: Android ~16 MB → 3.7 MB, iOS ~6 MB → 0.7 MB.

Gotchas when regenerating:
- The plugin rewrites `ios/Runner/Info.plist` (indentation only) — `git checkout -- ios/Runner/Info.plist` afterwards.
- `remove` leaves `drawable-night*/launch_background.xml` with **no logo layer** → dark mode on Android ≤11 shows an empty screen. Delete `drawable-night/` and `drawable-night-v21/` after `create` (already done).
- PIL quantization (256 colors) visibly bands the neon glow — don't use it. Use `pngquant` if more compression is needed.

Not yet verified on a real device: Android ≤11, Android 12+, iOS small screen (SE/mini), dark mode.

## 2. Home page (`lib/features/home/home_page.dart`) — IMPLEMENTED (Lavender Glass)

Constraint from owner: **keep `assets/BG_Portrait.png` as is** (pastel lavender, cat theme). Everything else must match the BG and feel premium.

Verdict: not premium yet. Findings, by impact:

1. **Bug — clipped square shadows** under BLE card, Controller and LineSonic cards. `boxShadow` lives on `Ink` inside `Card` (`home_page.dart` ~L501, ~L1010); shadow is clipped by the Material bounds → hard rectangular edges. Fix: move shadow to an outer `DecoratedBox`/`Container` around the card.
2. **Palette scattered** — 4 accent families (blue `#6F8FFF`, mint `#45D6A1`, orange `#FFB56B`, purple→cyan gradient). Mint and orange clash with lavender BG.
3. **Controller / LineSonic cards are empty** — 112 tall, tiny icon + title only, flat saturated fill hides the BG.
4. **Mixed icon styles** — `assets/icons/HomeUnified/*` 3D PNGs mixed with Material icons (facebook, download, open_in_new, bluetooth); Facebook icon is orange.
5. **No brand presence / generic typography** — Roboto everywhere, plain 18pt AppBar title. `Kanit` is already in `assets/fonts/` but not registered in `pubspec.yaml`.
6. **"No recent device yet" card** is a low-value empty state taking a full row.
7. **Version footer logo** — `logo_corner.png` (dark neon) at 0.42 opacity becomes a grey blob on lavender.
8. Dead code: all `isDark` branches — `main.dart` has no `darkTheme`, app is always light.
9. Minor: `isThai ? 'X' : 'X'` strings are identical in both branches.

Keep: information hierarchy (BLE status → main nav → secondary links), purple→cyan Scan button, content not covering the cat art at the bottom.

### Proposed direction — "Lavender Glass"

- Cards: frosted glass (`BackdropFilter` blur + white ~55% + thin white border), BG visible through.
- Palette: primary violet `#7256B6`, single accent cyan `#37D8FF`, text deep plum `#261B39`. Drop mint/orange.
- Controller / LineSonic: add subtitles ("Gamepad · Joystick", "PID · Sensor"), icon 40–48.
- Header: Kanit, small logo mark beside title, secondary greeting line.
- Secondary links: merge Contact + Arduino into one grouped list card with dividers, single icon style.
- Merge recent device into the BLE card (Reconnect when a last device exists, hide otherwise).
- Fix the shadow bug; delete dark-mode branches.

### Implemented (2026-11-02)

Owner approved "keep the BG, restyle everything else, animated BG welcome".

- `widgets/home_glass.dart` — `HomePalette` (violet `#7256B6` → cyan `#37D8FF`, ink `#261B39`), `GlassPanel` (backdrop blur + white glass + light rim; shadow painted only *outside* the rounded shape, so finding 1 is gone), `GradientActionButton`, `GlassActionButton`.
- `widgets/home_backdrop.dart` — `HomeBackdrop`: the untouched `BG_Portrait.png` plus an optional ambient-motion layer (drifting aurora light, twinkles on the sparkles already painted in the art, breathing glow on the collar / paw sign / cat-house door, floating motes). ~30 fps timer; stops when Home is covered by another page, when the app is backgrounded, and when the OS "remove animations" setting is on. `HomePage(animateBackground: false)` turns it off. Off by default under `flutter test`.
- Header: logo badge + Kanit title + "Robot remote by PrinceBot". The transparent AppBar gets a frosted strip once content scrolls under it (no more text overlapping the title).
- BLE hero card: status orb (spins while busy), device name as title when connected + signal bars + "Manage connection" button; hint line when not connected; **Reconnect** next to **Scan devices** when a last device exists. The separate "No recent device yet" card is removed.
- Controller / LineSonic: glass tiles tinted violet / cyan, 3D icon at 54 px, subtitles, arrow badge; single-column fallback below 314 px width.
- Contact + Arduino Library merged into one "Resources" glass list with matching violet line icons.
- Version line is text only (`PB Controller · vX`), no fallback version string.
- Content is capped at 560 px wide on tablets; spacing is on a 16 px rhythm.
- Pull-to-refresh (which used to open the BLE page) was removed; Scan devices is the entry point.
- Kanit Regular/Bold registered in `pubspec.yaml` (used for titles only).
- Dead `isDark` / `isThai` branches removed from Home.

Not yet verified on a real device: blur/animation smoothness on low-end Android, iOS.

### Resolved

- Splash vs Home theme jump: owner chose a lavender splash (see section 1).

### How the screenshot was taken

```
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell monkey -p com.pbcontroller.app -c android.intent.category.LAUNCHER 1
adb -s emulator-5554 exec-out screencap -p > home.png
```
