/// Reassembles `\n`-terminated ASCII protocol lines from BLE notifications.
///
/// A line may be split across notifications. `\r` is dropped so firmware that
/// prints with `println` (`\r\n`) works. A notification holding any other
/// non-printable byte is binary traffic and is ignored as a whole.
class BleProtocolLineAssembler {
  BleProtocolLineAssembler({this.maxBufferedChars = 512});

  /// An unterminated line longer than this is discarded, so a firmware that
  /// never sends `\n` cannot grow the buffer without bound.
  final int maxBufferedChars;

  final StringBuffer _buffer = StringBuffer();

  /// Returns the complete, trimmed, non-empty lines finished by [data].
  List<String> add(List<int> data) {
    final bytes = <int>[];
    for (final byte in data) {
      if (byte == 13) continue;
      if (byte != 10 && (byte < 32 || byte > 126)) return const [];
      bytes.add(byte);
    }
    if (bytes.isEmpty) return const [];

    _buffer.write(String.fromCharCodes(bytes));
    final parts = _buffer.toString().split('\n');
    final pending = parts.removeLast();
    _buffer.clear();
    if (pending.length <= maxBufferedChars) _buffer.write(pending);

    return [
      for (final line in parts)
        if (line.trim().isNotEmpty) line.trim(),
    ];
  }

  void reset() => _buffer.clear();
}
