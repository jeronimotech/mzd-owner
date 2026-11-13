import 'package:flutter/material.dart';

import '../state/app_state.dart';

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key, required this.state});
  final AppState state;

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  bool _reading = false;
  bool _explaining = false;
  String? _explanation;
  String? _error;

  Future<void> _read() async {
    setState(() {
      _reading = true;
      _error = null;
      _explanation = null;
    });
    try {
      await widget.state.readDtcs();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _reading = false);
  }

  Future<void> _explain(List<String> codes) async {
    setState(() {
      _explaining = true;
      _error = null;
    });
    try {
      final it = await widget.state.assistant.askAndWait(widget.state.dtcPrompt(codes));
      _explanation = it.answer;
    } catch (e) {
      _error = 'No se pudo consultar al asistente: $e';
    }
    if (mounted) setState(() => _explaining = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final codes = s.dtcs;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Diagnóstico', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Lee los códigos de falla del motor (check engine) y entiende qué significan.', style: TextStyle(color: Colors.white54)),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: s.connected && !_reading ? _read : null,
          icon: _reading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
          label: Text(s.connected ? 'Leer códigos de falla' : 'Conecta el carro en el Tablero'),
        ),
        const SizedBox(height: 20),
        if (codes != null && codes.isEmpty)
          const Card(child: ListTile(leading: Icon(Icons.verified, color: Color(0xFF33D17A)), title: Text('Sin códigos de falla'), subtitle: Text('El computador del carro no reporta problemas.'))),
        if (codes != null && codes.isNotEmpty) ...[
          for (final c in codes) ...[
            Card(child: ListTile(leading: const Icon(Icons.warning_amber, color: Colors.orangeAccent), title: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1)))),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _explaining ? null : () => _explain(codes),
            icon: _explaining ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: const Text('Explicar con IA'),
          ),
        ],
        if (_explanation != null) ...[
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_explanation!, style: const TextStyle(fontSize: 16, height: 1.45)))),
          const SizedBox(height: 8),
          const Text('Orientativo: confirma el diagnóstico con un taller.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
        ],
      ],
    );
  }
}
