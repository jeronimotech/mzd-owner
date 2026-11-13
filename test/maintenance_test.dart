import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mzd_owner/models/maintenance.dart';
import 'package:mzd_owner/models/vehicle.dart';
import 'package:mzd_owner/services/assistant_client.dart';
import 'package:mzd_owner/ui/format.dart';

void main() {
  final now = DateTime(2026, 11, 13);

  group('dueStatus', () {
    const oil = MaintenanceItem(id: 'oil', title: 'Aceite', everyKm: 10000, everyMonths: 12);

    test('unknown until the first service is logged', () {
      expect(dueStatus(oil, 50000, now).level, DueLevel.unknown);
    });

    test('ok, soon and overdue by distance', () {
      final done = oil.markDone(50000, now);
      expect(dueStatus(done, 52000, now).level, DueLevel.ok);
      expect(dueStatus(done, 59500, now).level, DueLevel.soon);
      final over = dueStatus(done, 60300, now);
      expect(over.level, DueLevel.due);
      expect(over.kmLeft, -300);
    });

    test('whichever comes first: time can make it due', () {
      final done = oil.markDone(50000, DateTime(2025, 10, 1));
      final s = dueStatus(done, 51000, now);
      expect(s.level, DueLevel.due);
      expect(s.daysLeft! < 0, isTrue);
      expect(s.label, contains('vencido hace'));
    });

    test('time-only items (SOAT)', () {
      const soat = MaintenanceItem(id: 'soat', title: 'SOAT', everyMonths: 12);
      final s = dueStatus(soat.markDone(0, DateTime(2025, 12, 1)), 0, now);
      expect(s.level, DueLevel.soon);
      expect(s.kmLeft, isNull);
    });

    test('labels format kilometres the Colombian way', () {
      final s = dueStatus(oil.markDone(50000, now), 51000, now);
      expect(s.label, startsWith('En 9.000 km'));
    });
  });

  test('default schedule has unique ids and every item has an interval', () {
    final items = defaultSchedule();
    expect(items.map((e) => e.id).toSet().length, items.length);
    expect(items.every((i) => i.everyKm != null || i.everyMonths != null), isTrue);
  });

  test('maintenance and profile survive a JSON round trip', () {
    final item = defaultSchedule().first.markDone(12345, now);
    final back = MaintenanceItem.fromJson(jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>);
    expect(back.lastKm, 12345);
    expect(back.lastDate, now);
    const p = CarProfile(plate: 'abc-123', odometerKm: 68420);
    expect(CarProfile.fromJson(p.toJson()).plateLastDigit, '3');
  });

  test('number formatting', () {
    expect(fmtNum(1794), '1.794');
    expect(fmtNum(14.25, decimals: 1, unit: 'V'), '14,3 V');
    expect(fmtNum(null), '--');
    expect(fmtKm(68420.4), '68.420 km');
  });

  group('AssistantClient', () {
    test('asks via POST and waits for the answer in the feed', () async {
      var polls = 0;
      final mock = MockClient((req) async {
        if (req.url.path.endsWith('/v1/assistant/ask')) {
          expect(req.method, 'POST');
          expect(jsonDecode(req.body)['source'], 'phone');
          expect(req.url.queryParameters['token'], 't0k');
          return http.Response(jsonEncode({'id': 7, 'q': 'hola', 'source': 'phone', 'status': 'pending', 'ts': 100, 'updated': 100}), 200);
        }
        polls++;
        final done = polls >= 2;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 7, 'q': 'hola', 'source': 'phone', 'status': done ? 'done' : 'pending', 'answer': done ? '¡Hola!' : null, 'ts': 100, 'updated': done ? 200 : 100},
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final c = AssistantClient(baseUrl: 'http://bridge.local:5173/bridge/', token: 't0k', client: mock);
      final it = await c.askAndWait('hola', timeout: const Duration(seconds: 10));
      expect(it.answer, '¡Hola!');
      expect(polls, greaterThanOrEqualTo(2));
    });

    test('keeps the bridge path prefix', () async {
      Uri? seen;
      final mock = MockClient((req) async {
        seen = req.url;
        return http.Response('{"ok":true}', 200);
      });
      expect(await AssistantClient(baseUrl: 'http://x:1/bridge', client: mock).ping(), isTrue);
      expect(seen!.path, '/bridge/v1/ping');
    });
  });
}
