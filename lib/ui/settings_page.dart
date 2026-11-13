import 'package:flutter/material.dart';

import '../state/app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state});
  final AppState state;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _name = TextEditingController(text: widget.state.profile.name);
  late final _model = TextEditingController(text: widget.state.profile.model);
  late final _year = TextEditingController(text: '${widget.state.profile.year}');
  late final _plate = TextEditingController(text: widget.state.profile.plate);
  late final _odo = TextEditingController(text: widget.state.profile.odometerKm.round().toString());
  late final _bridge = TextEditingController(text: widget.state.bridgeUrl);
  late final _token = TextEditingController(text: widget.state.bridgeToken);
  String? _bridgeStatus;

  Future<void> _saveProfile() async {
    final s = widget.state;
    await s.updateProfile(s.profile.copyWith(
      name: _name.text.trim().isEmpty ? 'Mi Mazda' : _name.text.trim(),
      model: _model.text.trim(),
      year: int.tryParse(_year.text) ?? s.profile.year,
      plate: _plate.text.trim().toUpperCase(),
      odometerKm: double.tryParse(_odo.text) ?? s.profile.odometerKm,
    ));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil guardado')));
  }

  Future<void> _testBridge() async {
    await widget.state.updateBridge(_bridge.text, _token.text);
    setState(() => _bridgeStatus = 'Probando…');
    final ok = await widget.state.assistant.ping();
    setState(() => _bridgeStatus = ok ? 'Conectado ✓' : 'No responde. ¿Está corriendo `mzd dev` o `mzd bridge`?');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('Ajustes', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Text('Mi carro', style: title),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre')),
        Row(children: [
          Expanded(flex: 2, child: TextField(controller: _model, decoration: const InputDecoration(labelText: 'Modelo'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _year, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Año'))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: _plate, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: 'Placa'))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _odo, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Odómetro (km)'))),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saveProfile, child: const Text('Guardar')),
        const Divider(height: 40),
        Text('Conexión con el carro', style: title),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo demo'),
          subtitle: const Text('Datos simulados mientras consigues el adaptador'),
          value: s.demoMode,
          onChanged: (v) => s.setDemoMode(v),
        ),
        if (!s.demoMode)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bluetooth),
            title: Text(s.adapterId == null ? 'Sin adaptador emparejado' : 'Adaptador recordado'),
            subtitle: const Text('Conecta un adaptador OBD-II Bluetooth LE (p. ej. Vgate iCar Pro BLE) al puerto bajo el timón, enciende el carro y toca Conectar en el Tablero.'),
          ),
        const Divider(height: 40),
        Text('Asistente (puente mzd-kit)', style: title),
        TextField(controller: _bridge, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL del puente', hintText: 'http://192.168.1.10:5173/bridge')),
        TextField(controller: _token, decoration: const InputDecoration(labelText: 'Token (opcional)')),
        const SizedBox(height: 12),
        Row(children: [
          OutlinedButton(onPressed: _testBridge, child: const Text('Guardar y probar')),
          const SizedBox(width: 12),
          if (_bridgeStatus != null) Expanded(child: Text(_bridgeStatus!, style: const TextStyle(color: Colors.white70))),
        ]),
        const SizedBox(height: 32),
        const Text('mzd-owner · código abierto (MIT) · github.com/jeronimotech/mzd-owner', textAlign: TextAlign.center, style: TextStyle(color: Colors.white24, fontSize: 12)),
      ],
    );
  }
}
