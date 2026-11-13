import 'package:flutter_test/flutter_test.dart';
import 'package:mzd_owner/obd/elm327.dart';

Pid pid(String code) => pids.firstWhere((p) => p.code == code);

void main() {
  group('parsePid', () {
    test('rpm with and without spaces, prompt and echo', () {
      expect(parsePid(pid('0C'), '41 0C 1A F8\r\r>'), 1726);
      expect(parsePid(pid('0C'), '010C\r410C1AF8\r>'), 1726);
    });

    test('speed, temperatures, voltage', () {
      expect(parsePid(pid('0D'), '410D3C'), 60);
      expect(parsePid(pid('05'), '41 05 7B'), 83);
      expect(parsePid(pid('46'), '41461C'), -12);
      expect(parsePid(pid('42'), '4142 3A 98'), closeTo(15.0, 0.001));
    });

    test('several ECUs answering: first valid line wins', () {
      expect(parsePid(pid('0D'), 'SEARCHING...\r410D28\r410D28\r>'), 40);
    });

    test('unsupported PIDs give null', () {
      expect(parsePid(pid('2F'), 'NO DATA\r>'), isNull);
      expect(parsePid(pid('2F'), '?\r>'), isNull);
      expect(parsePid(pid('0C'), '410C1A'), isNull); // truncated
    });
  });

  group('DTCs', () {
    test('decodes single codes', () {
      expect(decodeDtc(0x01, 0x33), 'P0133');
      expect(decodeDtc(0x04, 0x20), 'P0420');
      expect(decodeDtc(0xC1, 0x00), 'U0100');
      expect(decodeDtc(0x41, 0x23), 'C0123');
      expect(decodeDtc(0x00, 0x00), isNull);
    });

    test('CAN reply with count byte', () {
      expect(parseDtcs('43 02 01 33 04 20\r>'), ['P0133', 'P0420']);
    });

    test('legacy reply padded with zeros', () {
      expect(parseDtcs('43 01 33 00 00 00 00'), ['P0133']);
    });

    test('no codes', () {
      expect(parseDtcs('43 00\r>'), isEmpty);
      expect(parseDtcs('NO DATA'), isEmpty);
    });
  });
}
