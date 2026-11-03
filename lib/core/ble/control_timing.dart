/// Shared send-timing for all control pages (4 BTN, 8 BTN, Joystick).
///
/// Keep these in one place so the pages cannot drift apart again.
/// The robot-side watchdog stops the motors if no packet arrives for
/// 400 ms, so the active resend interval must leave room for several
/// consecutive lost packets.
library;

/// Firmware watchdog timeout (reference only; enforced on the robot).
const int kControlWatchdogMs = 400;

/// UI send-loop tick rate.
const int kLoopHz = 60;
const int kLoopMs = 1000 ~/ kLoopHz;

/// Resend interval while a control is held (unchanged packet).
const int kMinActiveMs = 50;

/// Keepalive interval while idle (repeats the current/zero packet so a
/// lost stop packet is recovered quickly).
const int kMinIdleMs = 150;

/// Hard cap on send rate.
const int kMaxSendHz = 40;
const int kMaxSendMs = 1000 ~/ kMaxSendHz;
