import 'package:flutter/widgets.dart';

import 'gamepad_appbar_controls.dart';

/// Warning notices of the layout editor. Overlap and boundary warnings show
/// at most once every 900 ms, since a drag hits them on every frame.
class GamepadEditNotices {
  static const _duration = Duration(milliseconds: 900);

  final String maxSizeMessage;
  final String minSizeMessage;
  int _lastOverlapWarningMs = 0;
  int _lastBoundaryWarningMs = 0;

  GamepadEditNotices({
    this.maxSizeMessage = 'Max size reached',
    this.minSizeMessage = 'Min size reached',
  });

  void showSizeLimit(BuildContext context, {required bool atMax}) {
    showGamepadTopNotice(
      context,
      message: atMax ? maxSizeMessage : minSizeMessage,
      duration: _duration,
      style: GamepadNoticeStyle.warning,
    );
  }

  void showBoundaryWarning(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastBoundaryWarningMs < 900) return;
    _lastBoundaryWarningMs = now;
    showGamepadTopNotice(
      context,
      message: 'Buttons must stay inside the safe zone.',
      duration: _duration,
      style: GamepadNoticeStyle.warning,
    );
  }

  void showOverlapWarning(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastOverlapWarningMs < 900) return;
    _lastOverlapWarningMs = now;
    showGamepadTopNotice(
      context,
      message: 'Buttons cannot overlap.',
      duration: _duration,
      style: GamepadNoticeStyle.warning,
    );
  }
}
