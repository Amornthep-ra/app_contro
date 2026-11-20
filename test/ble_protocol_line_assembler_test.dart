import 'package:flutter_test/flutter_test.dart';
import 'package:pb_controller/core/ble/ble_protocol_line_assembler.dart';

void main() {
  late BleProtocolLineAssembler assembler;

  setUp(() => assembler = BleProtocolLineAssembler(maxBufferedChars: 32));

  List<String> add(String text) => assembler.add(text.codeUnits);

  test('emits a plain newline-terminated line', () {
    expect(add('PB2:ERROR:AUTH_FAILED\n'), ['PB2:ERROR:AUTH_FAILED']);
  });

  test('accepts CRLF line endings from println firmware', () {
    expect(add('PB2:OK:s1:tag\r\n'), ['PB2:OK:s1:tag']);
    expect(add('A\r\nB\r\n'), ['A', 'B']);
  });

  test('joins a line split across notifications, including CR and LF', () {
    expect(add('PB2:CA'), isEmpty);
    expect(add('PS:2\r'), isEmpty);
    expect(add('\nNEXT'), ['PB2:CAPS:2']);
    expect(add('\n'), ['NEXT']);
  });

  test('skips empty lines', () {
    expect(add('\r\n\nX\n'), ['X']);
  });

  test('ignores a binary notification without disturbing a partial line', () {
    expect(add('PB2:'), isEmpty);
    expect(assembler.add(const [0xAA, 0x55, 0x02, 0x01]), isEmpty);
    expect(add('OK\n'), ['PB2:OK']);
  });

  test('drops an unterminated line that exceeds the buffer limit', () {
    expect(add('X' * 40), isEmpty);
    expect(add('Y\n'), ['Y']);
  });

  test('reset discards a partial line', () {
    expect(add('PARTIAL'), isEmpty);
    assembler.reset();
    expect(add('LINE\n'), ['LINE']);
  });
}
