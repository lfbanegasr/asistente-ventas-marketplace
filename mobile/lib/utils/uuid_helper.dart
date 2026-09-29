import 'dart:math';

class UuidHelper {
  static final Random _secureRandom = Random.secure();

  /// Genera un identificador UUID v4 estándar conforme a RFC 4122.
  static String generate() {
    final bytes = List<int>.generate(16, (_) => _secureRandom.nextInt(256));

    // Versión 4 (bits 12-15 del time_hi_and_version a 0100)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // Variante 1 (bits 6-7 de clock_seq_hi_and_reserved a 10)
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int byte) => byte.toRadixString(16).padLeft(2, '0');

    return '${bytes.sublist(0, 4).map(toHex).join()}-'
        '${bytes.sublist(4, 6).map(toHex).join()}-'
        '${bytes.sublist(6, 8).map(toHex).join()}-'
        '${bytes.sublist(8, 10).map(toHex).join()}-'
        '${bytes.sublist(10, 16).map(toHex).join()}';
  }
}
