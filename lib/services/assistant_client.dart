import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One question/answer in the assistant feed shared by the phone and the car (mzd-kit bridge).
class AssistantItem {
  AssistantItem({required this.id, required this.q, required this.source, required this.status, this.answer, required this.updated});

  final int id;
  final String q;
  final String source; // 'phone' | 'car'
  final String status; // 'pending' | 'done' | 'error'
  final String? answer;
  final int updated;

  bool get pending => status == 'pending';

  factory AssistantItem.fromJson(Map<String, dynamic> j) => AssistantItem(
        id: (j['id'] as num).toInt(),
        q: j['q'] as String,
        source: j['source'] as String? ?? 'phone',
        status: j['status'] as String? ?? 'pending',
        answer: j['answer'] as String?,
        updated: ((j['updated'] ?? j['ts']) as num).toInt(),
      );
}

/// Client for the mzd-kit bridge assistant (`/v1/assistant/*`). The Anthropic key lives on the
/// bridge, never in the app.
class AssistantClient {
  AssistantClient({required this.baseUrl, this.token, this.device, http.Client? client}) : _http = client ?? http.Client();

  String baseUrl;
  String? token;

  /// Random per-install id: on the shared cloud bridge each phone gets its own private feed.
  String? device;
  final http.Client _http;

  Uri _uri(String path, [Map<String, String>? q]) {
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl);
    final params = {...?q, if (token != null && token!.isNotEmpty) 'token': token!};
    return base.replace(path: '${base.path}$path', queryParameters: params.isEmpty ? null : params);
  }

  /// Sends a question. Optional car context (lat/lon/speed) helps location-aware answers.
  Future<AssistantItem> ask(String question, {double? lat, double? lon, double? speed}) async {
    final res = await _http
        .post(
          _uri('/v1/assistant/ask'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'q': question, 'source': 'phone', 'device': device, 'lat': lat, 'lon': lon, 'speed': speed}),
        )
        .timeout(const Duration(seconds: 10));
    if (res.statusCode == 429) {
      final msg = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['error'];
      throw msg is String ? msg : 'Demasiadas preguntas, intenta más tarde';
    }
    if (res.statusCode != 200) throw 'El puente respondió ${res.statusCode}';
    return AssistantItem.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  Future<List<AssistantItem>> feed(int since) async {
    final res = await _http.get(_uri('/v1/assistant/feed', {'since': '$since', 'device': ?device})).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw 'El puente respondió ${res.statusCode}';
    final d = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (d['items'] as List).map((e) => AssistantItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Asks and waits for the answer (polling the feed).
  Future<AssistantItem> askAndWait(String question, {Duration timeout = const Duration(seconds: 60)}) async {
    final item = await ask(question);
    final end = DateTime.now().add(timeout);
    var since = item.updated - 1;
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      for (final it in await feed(since)) {
        since = it.updated > since ? it.updated : since;
        if (it.id == item.id && !it.pending) return it;
      }
    }
    throw 'El asistente tardó demasiado';
  }

  Future<bool> ping() async {
    try {
      final res = await _http.get(_uri('/v1/ping')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
