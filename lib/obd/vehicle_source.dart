import 'dart:async';
import 'dart:math';

import '../models/vehicle.dart';

enum SourceState { disconnected, connecting, connected, error }

/// Where live vehicle data comes from (a Bluetooth OBD-II adapter, or the demo).
abstract class VehicleSource {
  String get name;
  Stream<VehicleSnapshot> get snapshots;
  Stream<SourceState> get states;
  SourceState get state;
  String? get lastError;

  Future<void> connect();
  Future<void> disconnect();

  /// Stored diagnostic trouble codes (mode 03).
  Future<List<String>> readDtcs();
}

/// Simulated drive: city traffic with stops, warming engine, slowly dropping fuel.
/// Used until the owner pairs an adapter, and for demos.
class DemoSource implements VehicleSource {
  DemoSource({this.dtcs = const ['P0420']});

  final List<String> dtcs;
  final _snap = StreamController<VehicleSnapshot>.broadcast();
  final _state = StreamController<SourceState>.broadcast();
  Timer? _timer;
  SourceState _current = SourceState.disconnected;
  double _t = 0;
  double _coolant = 28;
  double _fuel = 64;
  final _rand = Random(7);

  @override
  String get name => 'Modo demo';
  @override
  Stream<VehicleSnapshot> get snapshots => _snap.stream;
  @override
  Stream<SourceState> get states => _state.stream;
  @override
  SourceState get state => _current;
  @override
  String? get lastError => null;

  void _set(SourceState s) {
    _current = s;
    _state.add(s);
  }

  @override
  Future<void> connect() async {
    _set(SourceState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    _set(SourceState.connected);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _tick());
  }

  void _tick() {
    _t += 0.5;
    final c = _t % 40;
    final speed = c < 8 ? c * 6 : c < 22 ? 46 + sin(c) * 4 : c < 30 ? max(0.0, 46 - (c - 22) * 6) : 0.0;
    final gear = speed < 18 ? 120 : speed < 32 ? 66 : speed < 50 ? 46 : 36;
    final rpm = speed < 1 ? 760 + _rand.nextDouble() * 30 : max(900.0, speed * gear);
    _coolant = min(91, _coolant + 0.35);
    _fuel = max(0, _fuel - speed * 0.00004);
    _snap.add(VehicleSnapshot(
      speed: speed.toDouble(),
      rpm: rpm,
      coolantTemp: _coolant,
      intakeTemp: 22 + _rand.nextDouble() * 2,
      engineLoad: speed < 1 ? 18 : 25 + speed / 3,
      throttle: speed < 1 ? 0 : 12 + speed / 5,
      fuelLevel: _fuel,
      voltage: 14.2 + _rand.nextDouble() * 0.2,
      ambientTemp: 17,
      time: DateTime.now(),
    ));
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _set(SourceState.disconnected);
  }

  @override
  Future<List<String>> readDtcs() async => dtcs;
}
