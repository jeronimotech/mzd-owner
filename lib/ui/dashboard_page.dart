import 'dart:math';

import 'package:flutter/material.dart';

import '../obd/vehicle_source.dart';
import '../state/app_state.dart';
import 'format.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final v = state.live;
    final p = state.profile;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text('${p.model} ${p.year}${p.plate.isNotEmpty ? ' · ${p.plate.toUpperCase()}' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white54)),
            ]),
          ),
          _ConnectionChip(state: state),
        ]),
        const SizedBox(height: 20),
        _SpeedGauge(speed: v.speed, rpm: v.rpm, active: state.connected),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: [
            _Tile(icon: Icons.thermostat, label: 'Motor', value: fmtNum(v.coolantTemp, unit: '°'), warn: (v.coolantTemp ?? 0) > 105),
            _Tile(icon: Icons.battery_charging_full, label: 'Batería', value: fmtNum(v.voltage, decimals: 1, unit: 'V'), warn: v.voltage != null && (v.voltage! < 12.0 || v.voltage! > 15.0)),
            _Tile(icon: Icons.local_gas_station, label: 'Gasolina', value: fmtNum(v.fuelLevel, unit: '%'), warn: (v.fuelLevel ?? 100) < 12),
            _Tile(icon: Icons.air, label: 'Admisión', value: fmtNum(v.intakeTemp, unit: '°')),
            _Tile(icon: Icons.wb_sunny_outlined, label: 'Afuera', value: fmtNum(v.ambientTemp, unit: '°')),
            _Tile(icon: Icons.speed, label: 'Carga', value: fmtNum(v.engineLoad, unit: '%')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.route),
            title: Text(fmtKm(p.odometerKm)),
            subtitle: const Text('Odómetro estimado · corrígelo en Ajustes'),
          ),
        ),
        if (state.demoMode) ...[
          const SizedBox(height: 12),
          Text('Estás viendo datos de demostración. Conecta un adaptador OBD-II Bluetooth LE en Ajustes.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final st = state.sourceState;
    final (label, color) = switch (st) {
      SourceState.connected => (state.sourceName, const Color(0xFF33D17A)),
      SourceState.connecting => ('Conectando…', Colors.amber),
      SourceState.error => ('Error', Colors.orange),
      SourceState.disconnected => ('Conectar', Colors.white70),
    };
    return ActionChip(
      avatar: Icon(st == SourceState.connected ? Icons.bluetooth_connected : Icons.bluetooth, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color)),
      onPressed: st == SourceState.connecting
          ? null
          : () async {
              if (st == SourceState.connected) {
                await state.disconnect();
              } else {
                await state.connect();
                if (state.sourceState == SourceState.error && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.sourceError ?? 'No se pudo conectar')));
                }
              }
            },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value, this.warn = false});
  final IconData icon;
  final String label;
  final String value;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final color = warn ? Colors.orangeAccent : Colors.white;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Icon(icon, size: 20, color: warn ? Colors.orangeAccent : Colors.white54),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.white54)),
        ]),
      ),
    );
  }
}

class _SpeedGauge extends StatelessWidget {
  const _SpeedGauge({required this.speed, required this.rpm, required this.active});
  final double? speed;
  final double? rpm;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.6,
      child: CustomPaint(
        painter: _GaugePainter(rpmFraction: ((rpm ?? 0) / 7000).clamp(0, 1).toDouble(), color: Theme.of(context).colorScheme.primary),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(active ? fmtNum(speed) : '--', style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, height: 1)),
              const Text('KM/H', style: TextStyle(letterSpacing: 4, color: Colors.white54)),
              const SizedBox(height: 6),
              Text('${fmtNum(rpm)} rpm', style: const TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.rpmFraction, required this.color});
  final double rpmFraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.62);
    final radius = min(size.width / 2, size.height * 0.62) - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const start = pi * 0.85, sweep = pi * 1.3;
    final base = Paint()
      ..color = const Color(0xFF23262C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, base);
    if (rpmFraction > 0) {
      final fg = Paint()
        ..shader = SweepGradient(
          startAngle: start,
          endAngle: start + sweep,
          colors: [color.withValues(alpha: 0.6), color, rpmFraction > 0.8 ? Colors.orangeAccent : color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start, sweep * rpmFraction, false, fg);
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.rpmFraction != rpmFraction || old.color != color;
}
