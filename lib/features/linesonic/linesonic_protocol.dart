/// Text commands between the app and the PB-LineSonic board firmware
/// (kbide plugin `PB-LineSonic`, src/PBLineSonic.cpp).
///
/// The board reads each BLE write as one whole command: `SEQ=` steps are
/// split on `;` and fields on `,`, integers with `String.toInt()` and
/// KP/KD with `String.toFloat()`. Pure Dart, so it is unit tested.
library;

/// How a step decides it is done (firmware `parseMode`).
enum LineSonicStepMode {
  /// Run for [LineSonicStep.value] milliseconds.
  time,

  /// Run until the sum of the light sensors reaches [LineSonicStep.value].
  checksum,
}

/// One step of a `SEQ=` sequence, as numbers.
class LineSonicStep {
  const LineSonicStep({
    required this.mode,
    required this.value,
    required this.kp,
    required this.kd,
    required this.speed,
    required this.afterMs,
    required this.afterSpeed,
    required this.stopMs,
    required this.lineColor,
    required this.holdMs,
    required this.holdThreshold,
    required this.holdMode,
  });

  /// Null when the user has not picked one yet; sent as TIME, as before.
  final LineSonicStepMode? mode;
  final int value;
  final double kp;
  final double kd;
  final int speed;
  final int afterMs;

  /// 0 makes the board reuse [speed].
  final int afterSpeed;
  final int stopMs;

  /// 0 = black line, 1 = white line.
  final int lineColor;
  final int holdMs;
  final int holdThreshold;

  /// 0 = off, 1 = all black, 2 = all white.
  final int holdMode;
}

/// A step field, named as on the PID page.
enum LineSonicField {
  value('Milliseconds (ms)'),
  checksumValue('Line Count / Target'),
  kp('KP'),
  kd('KD'),
  speed('Speed'),
  afterMs('Continue (ms)'),
  afterSpeed('Continue Speed'),
  stopMs('Stop (ms)'),
  holdMs('Straight (ms)'),
  holdThreshold('SUM threshold');

  const LineSonicField(this.label);
  final String label;
}

/// Why one field of one step cannot be sent.
class LineSonicFieldError {
  const LineSonicFieldError(this.step, this.field, this.message);

  /// 1-based step number, as shown on the page.
  final int step;
  final LineSonicField field;
  final String message;

  @override
  String toString() => 'Step $step · ${field.label}: $message';
}

/// The raw text of a step's fields, before checking.
class LineSonicStepInput {
  const LineSonicStepInput({
    required this.mode,
    required this.value,
    required this.kp,
    required this.kd,
    required this.speed,
    required this.afterMs,
    required this.afterSpeed,
    required this.stopMs,
    required this.holdMs,
    required this.holdThreshold,
    required this.lineColor,
    required this.holdMode,
    required this.continueAfter,
    required this.stopBetween,
  });

  final LineSonicStepMode? mode;
  final String value;
  final String kp;
  final String kd;
  final String speed;
  final String afterMs;
  final String afterSpeed;
  final String stopMs;
  final String holdMs;
  final String holdThreshold;
  final int lineColor;
  final int holdMode;
  final bool continueAfter;
  final bool stopBetween;
}

/// The checked steps, or what is wrong with them.
class LineSonicSequenceResult {
  const LineSonicSequenceResult._(
    this.steps,
    this.errors, {
    this.tooManySteps = false,
  });

  final List<LineSonicStep> steps;
  final List<LineSonicFieldError> errors;

  /// More than [LineSonicProtocol.maxSteps]: the board would drop the rest.
  final bool tooManySteps;

  bool get ok => errors.isEmpty && !tooManySteps;
}

/// One `SENS=` line from the board.
class LineSonicSensorReading {
  const LineSonicSensorReading(this.values, this.sum);

  final List<int> values;

  /// Only lines from `PBLineSonic_sendAdcAll` carry `SUM=`.
  final int? sum;
}

abstract final class LineSonicProtocol {
  /// Firmware `PB_LINESONIC_MAX_SEQ`: steps past this are dropped.
  static const maxSteps = 20;

  /// Motor speed limit in `lineFollow_PID`.
  static const maxSpeed = 100;

  /// `ReadLightSensor` returns 0–100 for each of up to 8 sensors.
  static const maxSensorSum = 800;

  /// Largest value `String.toInt()` reads into an ESP32 `int`.
  static const maxInt = 2147483647;

  static const sw1 = 'SW1=1';
  static const reset = 'RESET=1';
  static const sensorRead = 'SENS=1';

  static final _number = RegExp(r'^-?(\d+\.?\d*|\.\d+)$');

  /// A number typed in a field: blank is 0 (as before), `,` is read as
  /// the decimal point and Thai digits are accepted. Null when it is not a
  /// plain decimal number.
  static double? parseNumber(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return 0;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      // Thai digits ๐–๙ are U+0E50–U+0E59.
      buffer.writeCharCode(
        rune >= 0x0E50 && rune <= 0x0E59 ? rune - 0x0E50 + 0x30 : rune,
      );
    }
    text = buffer.toString().replaceAll(',', '.');
    if (!_number.hasMatch(text)) return null;
    return double.tryParse(text);
  }

  /// Checks and converts the steps. Only fields the board will use are
  /// checked: a hidden option that is switched off is sent as 0.
  static LineSonicSequenceResult checkSteps(List<LineSonicStepInput> inputs) {
    final errors = <LineSonicFieldError>[];
    final steps = <LineSonicStep>[];
    for (var i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final number = i + 1;

      double? decimal(String raw, LineSonicField field) {
        final value = parseNumber(raw);
        if (value == null) {
          errors.add(LineSonicFieldError(number, field, 'Enter a number.'));
          return null;
        }
        if (value < 0) {
          errors.add(LineSonicFieldError(number, field, 'Must be 0 or more.'));
          return null;
        }
        return value;
      }

      int? whole(String raw, LineSonicField field, int max) {
        final value = decimal(raw, field);
        if (value == null) return null;
        if (value != value.truncateToDouble()) {
          errors.add(LineSonicFieldError(number, field, 'Use a whole number.'));
          return null;
        }
        if (value > max) {
          errors.add(
            LineSonicFieldError(number, field, 'Must be $max or less.'),
          );
          return null;
        }
        return value.toInt();
      }

      final checksum = input.mode == LineSonicStepMode.checksum;
      final value = checksum
          ? whole(input.value, LineSonicField.checksumValue, maxSensorSum)
          : whole(input.value, LineSonicField.value, maxInt);
      final kp = decimal(input.kp, LineSonicField.kp);
      final kd = decimal(input.kd, LineSonicField.kd);
      final speed = whole(input.speed, LineSonicField.speed, maxSpeed);
      final afterMs = input.continueAfter
          ? whole(input.afterMs, LineSonicField.afterMs, maxInt)
          : 0;
      final afterSpeed = input.continueAfter
          ? whole(input.afterSpeed, LineSonicField.afterSpeed, maxSpeed)
          : 0;
      final stopMs = input.stopBetween
          ? whole(input.stopMs, LineSonicField.stopMs, maxInt)
          : 0;
      final holding = input.holdMode != 0;
      final holdMs = holding
          ? whole(input.holdMs, LineSonicField.holdMs, maxInt)
          : 0;
      final holdThreshold = holding
          ? whole(
              input.holdThreshold,
              LineSonicField.holdThreshold,
              maxSensorSum,
            )
          : 0;
      if (value == null ||
          kp == null ||
          kd == null ||
          speed == null ||
          afterMs == null ||
          afterSpeed == null ||
          stopMs == null ||
          holdMs == null ||
          holdThreshold == null) {
        continue;
      }
      steps.add(
        LineSonicStep(
          mode: input.mode,
          value: value,
          kp: kp,
          kd: kd,
          speed: speed,
          afterMs: afterMs,
          afterSpeed: afterSpeed,
          stopMs: stopMs,
          lineColor: input.lineColor,
          holdMs: holdMs,
          holdThreshold: holdThreshold,
          holdMode: input.holdMode,
        ),
      );
    }
    final tooMany = inputs.length > maxSteps;
    return LineSonicSequenceResult._(
      errors.isEmpty && !tooMany ? steps : const [],
      errors,
      tooManySteps: tooMany,
    );
  }

  /// `SEQ=mode,value,kp,kd,speed,afterMs,afterSpeed,stopMs,lineColor,
  /// holdMs,holdThreshold,holdMode;...` (field order of `parseSequence`).
  static String sequence(List<LineSonicStep> steps) {
    final parts = steps.map(
      (s) => [
        s.mode == LineSonicStepMode.checksum ? 'CHECKSUM' : 'TIME',
        s.value,
        formatDecimal(s.kp),
        formatDecimal(s.kd),
        s.speed,
        s.afterMs,
        s.afterSpeed,
        s.stopMs,
        s.lineColor,
        s.holdMs,
        s.holdThreshold,
        s.holdMode,
      ].join(','),
    );
    return 'SEQ=${parts.join(';')}';
  }

  /// `SEQPD=kp,kd,speed;...`: updates the steps already on the board.
  static String sequencePd(List<LineSonicStep> steps) {
    final parts = steps.map(
      (s) => '${formatDecimal(s.kp)},${formatDecimal(s.kd)},${s.speed}',
    );
    return 'SEQPD=${parts.join(';')}';
  }

  /// A decimal for `String.toFloat()`: `.` as the point, no exponent, no
  /// trailing zeros.
  static String formatDecimal(double value) {
    if (value == value.truncateToDouble()) return value.toInt().toString();
    var text = value.toStringAsFixed(6);
    text = text.replaceFirst(RegExp(r'0+$'), '');
    return text.endsWith('.') ? text.substring(0, text.length - 1) : text;
  }

  /// Whether [command] reaches the board in one BLE write. The app adds a
  /// `\n` and splits longer text, but the board reads every write as a
  /// separate command, so a split `SEQ=` would lose its later steps.
  static bool fitsInOneWrite(String command, {required int payloadSize}) =>
      command.length + 1 <= payloadSize;

  /// How many of [steps] fit in one write of [payloadSize] when sent with
  /// [build] ([sequence] or [sequencePd]).
  static int stepsThatFit(
    List<LineSonicStep> steps, {
    required int payloadSize,
    String Function(List<LineSonicStep> steps) build = sequence,
  }) {
    var count = 0;
    while (count < steps.length &&
        fitsInOneWrite(
          build(steps.sublist(0, count + 1)),
          payloadSize: payloadSize,
        )) {
      count++;
    }
    return count;
  }

  /// Reads `SENS=12,34,...` or `SENS=12,34,...,SUM=46`. Null for any
  /// other line (such as the board's `ACK`) or one with no sensor value.
  static LineSonicSensorReading? parseSensorLine(String line) {
    final text = line.trim();
    if (!text.toUpperCase().startsWith('SENS=')) return null;
    final values = <int>[];
    int? sum;
    for (final raw in text.substring(5).split(',')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (part.toUpperCase().startsWith('SUM=')) {
        sum = int.tryParse(part.substring(4).trim()) ?? sum;
        continue;
      }
      final value = int.tryParse(part);
      if (value == null) return null;
      values.add(value);
    }
    if (values.isEmpty) return null;
    return LineSonicSensorReading(List.unmodifiable(values), sum);
  }
}
