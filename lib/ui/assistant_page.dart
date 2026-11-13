import 'dart:async';

import 'package:flutter/material.dart';

import '../services/assistant_client.dart';
import '../services/voice.dart';
import '../state/app_state.dart';

const quickQuestions = [
  '¿Hay pico y placa hoy?',
  '¿Qué hay cerca para comer?',
  '¿Dónde hay una gasolinera cerca?',
  'Resúmeme las noticias',
  '¿Cómo estará el clima esta tarde?',
];

class AssistantPage extends StatefulWidget {
  const AssistantPage({super.key, required this.state});
  final AppState state;

  @override
  State<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends State<AssistantPage> {
  final _voice = Voice();
  final _text = TextEditingController();
  final Map<int, AssistantItem> _items = {};
  final Set<int> _spoken = {};
  Timer? _poll;
  int _since = 0;
  bool _listening = false;
  bool _speak = true;
  String? _error;
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _voice.quiet();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final items = await widget.state.assistant.feed(_since);
      if (!mounted) return;
      for (final it in items) {
        _since = it.updated > _since ? it.updated : _since;
        _items[it.id] = it;
        if (!it.pending && !_spoken.contains(it.id)) {
          _spoken.add(it.id);
          if (!_first && _speak && it.answer != null) _voice.say(it.answer!);
        }
      }
      _first = false;
      setState(() => _error = null);
    } catch (e) {
      if (mounted) setState(() => _error = 'No hay conexión con el puente (${widget.state.bridgeUrl}). Revísalo en Ajustes.');
    }
  }

  Future<void> _ask(String q) async {
    q = q.trim();
    if (q.isEmpty) return;
    _text.clear();
    try {
      final it = await widget.state.assistant.ask(q, speed: widget.state.live.speed);
      setState(() => _items[it.id] = it);
    } catch (e) {
      setState(() => _error = 'No se pudo enviar: $e');
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _voice.stop();
      setState(() => _listening = false);
      return;
    }
    await _voice.quiet();
    final ok = await _voice.listen(
      onPartial: (t) => setState(() => _text.text = t),
      onDone: (t) {
        setState(() => _listening = false);
        _ask(t);
      },
    );
    setState(() {
      _listening = ok;
      if (!ok) _error = 'Permite el micrófono y el reconocimiento de voz en Ajustes del iPhone.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _items.values.toList()..sort((a, b) => b.id.compareTo(a.id));
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
        child: Row(children: [
          Expanded(child: Text('Asistente', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
          const Text('Leer en voz alta', style: TextStyle(color: Colors.white54)),
          Switch(value: _speak, onChanged: (v) => setState(() => _speak = v)),
        ]),
      ),
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [for (final q in quickQuestions) Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(q), onPressed: () => _ask(q)))],
        ),
      ),
      if (_error != null) Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 0), child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
      Expanded(
        child: items.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Pregúntale algo a tu carro.\nLa respuesta también aparece en la pantalla del Mazda.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${it.source == 'car' ? 'Desde el carro' : 'Tú'} · ${it.q}', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          it.pending ? 'Pensando…' : (it.answer ?? ''),
                          style: TextStyle(fontSize: 16, height: 1.4, color: it.status == 'error' ? Colors.orangeAccent : null, fontStyle: it.pending ? FontStyle.italic : null),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              decoration: InputDecoration(
                hintText: _listening ? 'Escuchando…' : 'Pregúntale algo al carro…',
                filled: true,
                fillColor: const Color(0xFF17191D),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 60,
            height: 60,
            child: FloatingActionButton(
              heroTag: 'mic',
              onPressed: _toggleMic,
              backgroundColor: _listening ? Colors.redAccent : Theme.of(context).colorScheme.primary,
              child: Icon(_listening ? Icons.stop : Icons.mic, size: 28),
            ),
          ),
        ]),
      ),
    ]);
  }
}
