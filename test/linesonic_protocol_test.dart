import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/features/linesonic/linesonic_protocol.dart';

LineSonicStepInput input({
  LineSonicStepMode? mode = LineSonicStepMode.time,
  String value = '1000',
  String kp = '1.5',
  String kd = '0.8',
  String speed = '50',
  String afterMs = '0',
  String afterSpeed = '0',
  String stopMs = '0',
  String holdMs = '0',
  String holdThreshold = '0',
  int lineColor = 0,
  int holdMode = 0,
  bool continueAfter = false,
  bool stopBetween = false,
}) => LineSonicStepInput(
  mode: mode,
  value: value,
  kp: kp,
  kd: kd,
  speed: speed,
  afterMs: afterMs,
  afterSpeed: afterSpeed,
  stopMs: stopMs,
  holdMs: holdMs,
  holdThreshold: holdThreshold,
  lineColor: lineColor,
  holdMode: holdMode,
  continueAfter: continueAfter,
  stopBetween: stopBetween,
);

List<LineSonicStep> steps(List<LineSonicStepInput> inputs) {
  final result = LineSonicProtocol.checkSteps(inputs);
  expect(result.ok, isTrue, reason: result.errors.join('\n'));
  return result.steps;
}

void main() {
  group('payloads', () {
    test('SEQ= keeps the field order the board parses', () {
      final payload = LineSonicProtocol.sequence(
        steps([
          input(),
          input(
            mode: LineSonicStepMode.checksum,
            value: '420',
            kp: '2',
            kd: '1.25',
            speed: '70',
            continueAfter: true,
            afterMs: '200',
            afterSpeed: '40',
            stopBetween: true,
            stopMs: '300',
            lineColor: 1,
            holdMode: 1,
            holdMs: '150',
            holdThreshold: '700',
          ),
        ]),
      );
      // The same text the page sent before for these fields.
      expect(
        payload,
        'SEQ=TIME,1000,1.5,0.8,50,0,0,0,0,0,0,0;'
        'CHECKSUM,420,2,1.25,70,200,40,300,1,150,700,1',
      );
    });

    test('SEQPD= sends KP, KD and Speed of each step', () {
      final payload = LineSonicProtocol.sequencePd(
        steps([input(), input(kp: '3', kd: '0.05', speed: '100')]),
      );
      expect(payload, 'SEQPD=1.5,0.8,50;3,0.05,100');
    });

    test('options that are off are sent as 0, as before', () {
      final payload = LineSonicProtocol.sequence(
        steps([
          input(
            afterMs: '999',
            afterSpeed: '99',
            stopMs: '999',
            holdMs: '999',
            holdThreshold: '999',
          ),
        ]),
      );
      expect(payload, 'SEQ=TIME,1000,1.5,0.8,50,0,0,0,0,0,0,0');
    });

    test('a step with no mode yet is refused', () {
      final result = LineSonicProtocol.checkSteps([input(), input(mode: null)]);
      expect(result.ok, isFalse);
      expect(result.errors.single.step, 2);
      expect(result.errors.single.field, LineSonicField.mode);
      expect(
        result.errors.single.toString(),
        'Step 2 · Mode: Pick Time or CheckSum.',
      );
    });

    test('a length or target of 0 is refused; 1 is fine', () {
      final time = LineSonicProtocol.checkSteps([input(value: '0')]);
      expect(time.errors.single.field, LineSonicField.value);
      expect(
        time.errors.single.message,
        'Must be more than 0, or turn on Continue or Stop.',
      );

      final checksum = LineSonicProtocol.checkSteps([
        input(mode: LineSonicStepMode.checksum, value: ''),
      ]);
      expect(checksum.errors.single.field, LineSonicField.checksumValue);

      steps([input(value: '1')]);
      steps([input(mode: LineSonicStepMode.checksum, value: '1')]);
    });

    test('a 0 step with Continue or Stop on is sent: the board still runs '
        'them', () {
      final payload = LineSonicProtocol.sequence(
        steps([
          input(
            value: '0',
            continueAfter: true,
            afterMs: '300',
            afterSpeed: '40',
          ),
          input(
            mode: LineSonicStepMode.checksum,
            value: '0',
            stopBetween: true,
            stopMs: '500',
          ),
        ]),
      );
      expect(
        payload,
        'SEQ=TIME,0,1.5,0.8,50,300,40,0,0,0,0,0;'
        'CHECKSUM,0,1.5,0.8,50,0,0,500,0,0,0,0',
      );
    });

    test('a 0 step that would still do nothing is refused', () {
      for (final step in [
        // Switched on with 0 ms.
        input(value: '0', continueAfter: true, afterMs: '0'),
        input(value: '0', stopBetween: true, stopMs: '0'),
        // A time set but the option off.
        input(value: '0', afterMs: '300', stopMs: '500'),
        // Straight runs inside the step, so it never starts.
        input(value: '0', holdMode: 1, holdMs: '200', holdThreshold: '10'),
      ]) {
        final result = LineSonicProtocol.checkSteps([step]);
        expect(result.ok, isFalse);
        expect(result.errors.single.field, LineSonicField.value);
      }
    });

    test('a 0 step with a bad Continue time names only that field', () {
      final result = LineSonicProtocol.checkSteps([
        input(value: '0', continueAfter: true, afterMs: 'x'),
      ]);
      expect(result.errors.single.field, LineSonicField.afterMs);
    });

    test('fixed commands', () {
      expect(LineSonicProtocol.sw1, 'SW1=1');
      expect(LineSonicProtocol.reset, 'RESET=1');
      expect(LineSonicProtocol.sensorRead, 'SENS=1');
    });
  });

  group('numbers', () {
    test('comma, Thai digits and blanks', () {
      expect(LineSonicProtocol.parseNumber('1,5'), 1.5);
      expect(LineSonicProtocol.parseNumber(' 1.5 '), 1.5);
      expect(LineSonicProtocol.parseNumber('๑๒'), 12);
      expect(LineSonicProtocol.parseNumber('.5'), 0.5);
      expect(LineSonicProtocol.parseNumber(''), 0);
    });

    test('anything but a plain number is refused', () {
      for (final raw in ['1;2', '1 2', '1.2.3', '1e3', 'NaN', 'abc', '--1']) {
        expect(LineSonicProtocol.parseNumber(raw), isNull, reason: raw);
      }
    });

    test('decimals are written for String.toFloat()', () {
      expect(LineSonicProtocol.formatDecimal(2), '2');
      expect(LineSonicProtocol.formatDecimal(1.50), '1.5');
      expect(LineSonicProtocol.formatDecimal(0.000001), '0.000001');
      expect(LineSonicProtocol.formatDecimal(1e-9), '0');
    });

    test('a comma typed in KP no longer shifts the later fields', () {
      final payload = LineSonicProtocol.sequence(steps([input(kp: '1,5')]));
      expect(payload, 'SEQ=TIME,1000,1.5,0.8,50,0,0,0,0,0,0,0');
    });
  });

  group('checks', () {
    LineSonicFieldError onlyError(LineSonicStepInput step) {
      final result = LineSonicProtocol.checkSteps([input(), step]);
      expect(result.ok, isFalse);
      expect(result.steps, isEmpty);
      expect(result.errors, hasLength(1));
      expect(result.errors.single.step, 2);
      return result.errors.single;
    }

    test('ranges from the firmware', () {
      expect(onlyError(input(speed: '101')).field, LineSonicField.speed);
      expect(onlyError(input(speed: '-1')).field, LineSonicField.speed);
      expect(onlyError(input(speed: '50.7')).field, LineSonicField.speed);
      expect(onlyError(input(kp: '-0.1')).field, LineSonicField.kp);
      expect(onlyError(input(kd: 'x')).field, LineSonicField.kd);
      expect(
        onlyError(input(mode: LineSonicStepMode.checksum, value: '801')).field,
        LineSonicField.checksumValue,
      );
      expect(
        onlyError(input(holdMode: 2, holdThreshold: '900')).field,
        LineSonicField.holdThreshold,
      );
      expect(
        onlyError(input(continueAfter: true, afterSpeed: '120')).field,
        LineSonicField.afterSpeed,
      );
    });

    test('whole numbers typed with .0 are accepted', () {
      final payload = LineSonicProtocol.sequence(steps([input(speed: '50.0')]));
      expect(payload, contains(',50,'));
    });

    test('a long TIME is fine; CHECKSUM is capped at the sensor sum', () {
      steps([input(value: '120000')]);
      steps([input(mode: LineSonicStepMode.checksum, value: '800')]);
    });

    test('more than 20 steps is refused', () {
      final result = LineSonicProtocol.checkSteps(
        List.generate(LineSonicProtocol.maxSteps + 1, (_) => input()),
      );
      expect(result.tooManySteps, isTrue);
      expect(result.ok, isFalse);
      expect(result.steps, isEmpty);
    });
  });

  group('one write', () {
    test('the command plus its newline must fit the payload', () {
      expect(
        LineSonicProtocol.fitsInOneWrite('A' * 19, payloadSize: 20),
        isTrue,
      );
      expect(
        LineSonicProtocol.fitsInOneWrite('A' * 20, payloadSize: 20),
        isFalse,
      );
    });

    test('how many steps fit a phone payload', () {
      final many = steps(List.generate(20, (_) => input()));
      final perStep = LineSonicProtocol.sequence(many.sublist(0, 1)).length;
      final fit182 = LineSonicProtocol.stepsThatFit(many, payloadSize: 182);
      final fit509 = LineSonicProtocol.stepsThatFit(many, payloadSize: 509);
      expect(fit182, lessThan(fit509));
      expect(fit509, lessThan(20));
      expect(
        LineSonicProtocol.sequence(many.sublist(0, fit182)).length + 1,
        lessThanOrEqualTo(182),
      );
      expect(
        LineSonicProtocol.sequence(many.sublist(0, fit182 + 1)).length + 1,
        greaterThan(182),
      );
      expect(perStep, greaterThan(30));
      // SEQPD= is shorter, so more steps fit.
      expect(
        LineSonicProtocol.stepsThatFit(
          many,
          payloadSize: 182,
          build: LineSonicProtocol.sequencePd,
        ),
        greaterThan(fit182),
      );
    });
  });

  group('sensor lines', () {
    test('with and without SUM', () {
      final adc = LineSonicProtocol.parseSensorLine('SENS=1203,998,4095')!;
      expect(adc.values, [1203, 998, 4095]);
      expect(adc.sum, isNull);

      final light = LineSonicProtocol.parseSensorLine(
        ' SENS=10, 20,30,SUM=60\r',
      )!;
      expect(light.values, [10, 20, 30]);
      expect(light.sum, 60);
    });

    test('other lines and broken lines are ignored', () {
      for (final line in ['ACK', '', 'SENS=', 'SENS=SUM=5', 'SENS=1,x,3']) {
        expect(LineSonicProtocol.parseSensorLine(line), isNull, reason: line);
      }
    });
  });
}
