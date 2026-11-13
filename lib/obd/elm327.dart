/// ELM327 protocol helpers (pure Dart, no I/O) — commands and response parsing for
/// the OBD-II PIDs we read from the car. Kept free of Bluetooth so it is unit-testable.
library;

/// Initialization sequence: reset, echo/linefeeds/spaces/headers off, automatic protocol.
const elmInitCommands = ['ATZ', 'ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0'];

/// A mode-01 PID we know how to decode.
class Pid {
  const Pid(this.code, this.key, this.bytes, this.decode);

  /// Hex PID, e.g. "0C".
  final String code;

  /// Field name in [VehicleSnapshot].
  final String key;

  /// Number of data bytes expected.
  final int bytes;
  final double Function(List<int> d) decode;

  String get command => '01$code';
}

final pids = <Pid>[
  Pid('0D', 'speed', 1, (d) => d[0].toDouble()), // km/h
  Pid('0C', 'rpm', 2, (d) => ((d[0] * 256) + d[1]) / 4),
  Pid('05', 'coolantTemp', 1, (d) => d[0] - 40.0), // °C
  Pid('0F', 'intakeTemp', 1, (d) => d[0] - 40.0), // °C
  Pid('04', 'engineLoad', 1, (d) => d[0] * 100 / 255), // %
  Pid('11', 'throttle', 1, (d) => d[0] * 100 / 255), // %
  Pid('2F', 'fuelLevel', 1, (d) => d[0] * 100 / 255), // % (not every car reports it)
  Pid('42', 'voltage', 2, (d) => ((d[0] * 256) + d[1]) / 1000), // V
  Pid('46', 'ambientTemp', 1, (d) => d[0] - 40.0), // °C
];

/// Normalizes a raw ELM327 reply: drops the '>' prompt, echoes, spaces and status lines.
List<String> cleanLines(String raw) => raw
    .replaceAll('>', '')
    .split(RegExp(r'[\r\n]+'))
    .map((l) => l.replaceAll(' ', '').trim().toUpperCase())
    .where((l) => l.isNotEmpty && l != 'SEARCHING...' && !l.startsWith('BUSINIT'))
    .toList();

/// True when the adapter or car reported that no answer is available.
bool isNoData(String raw) {
  final up = raw.toUpperCase();
  return up.contains('NODATA') ||
      up.contains('NO DATA') ||
      up.contains('UNABLETOCONNECT') ||
      up.contains('UNABLE TO CONNECT') ||
      up.contains('CAN ERROR') ||
      up.contains('STOPPED') ||
      up.trim() == '?';
}

List<int> _hexBytes(String hex) {
  final out = <int>[];
  for (var i = 0; i + 1 < hex.length; i += 2) {
    final b = int.tryParse(hex.substring(i, i + 2), radix: 16);
    if (b == null) return const [];
    out.add(b);
  }
  return out;
}

/// Decodes a mode-01 reply for [pid]. Returns null when the car doesn't support it.
/// Handles multiple ECUs answering (takes the first valid line).
double? parsePid(Pid pid, String raw) {
  if (isNoData(raw)) return null;
  final prefix = '41${pid.code}';
  for (final line in cleanLines(raw)) {
    final i = line.indexOf(prefix);
    if (i < 0) continue;
    final data = _hexBytes(line.substring(i + prefix.length));
    if (data.length < pid.bytes) continue;
    return pid.decode(data.sublist(0, pid.bytes));
  }
  return null;
}

const _dtcLetters = ['P', 'C', 'B', 'U'];

/// Decodes one two-byte DTC (e.g. 0x01 0x33 → "P0133"). Returns null for padding (0000).
String? decodeDtc(int a, int b) {
  if (a == 0 && b == 0) return null;
  final letter = _dtcLetters[(a & 0xC0) >> 6];
  final d1 = (a & 0x30) >> 4;
  final d2 = a & 0x0F;
  return '$letter$d1${d2.toRadixString(16).toUpperCase()}'
      '${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

/// Parses a mode-03 reply (stored trouble codes). Works for CAN replies, which carry a
/// count byte after "43", and legacy replies without it.
List<String> parseDtcs(String raw) {
  if (isNoData(raw)) return const [];
  final codes = <String>{};
  for (final line in cleanLines(raw)) {
    final i = line.indexOf('43');
    if (i < 0) continue;
    var data = _hexBytes(line.substring(i + 2));
    // CAN: first byte is the number of codes, followed by 2 bytes per code.
    if (data.isNotEmpty && data.length.isOdd && data[0] * 2 == data.length - 1) {
      data = data.sublist(1);
    }
    for (var j = 0; j + 1 < data.length; j += 2) {
      final code = decodeDtc(data[j], data[j + 1]);
      if (code != null) codes.add(code);
    }
  }
  return codes.toList()..sort();
}
