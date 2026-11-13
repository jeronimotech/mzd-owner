import 'dart:async';
import 'dart:convert';

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/maintenance.dart';
import '../models/vehicle.dart';
import '../obd/ble_obd_source.dart';
import '../obd/vehicle_source.dart';
import '../services/assistant_client.dart';

/// Single source of truth for the phone UI and the CarPlay / Android Auto screens.
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  static Future<AppState> load() async {
    final s = AppState(await SharedPreferences.getInstance());
    s._restore();
    return s;
  }

  final SharedPreferences _prefs;

  CarProfile profile = const CarProfile();
  List<MaintenanceItem> maintenance = defaultSchedule();
  bool demoMode = true;
  String? adapterId;
  /// Cloud bridge (mzd-kit on Railway). Overridable at build time and in Ajustes → Avanzado.
  static const defaultBridgeUrl = String.fromEnvironment('MZD_BRIDGE_URL', defaultValue: 'https://mzd-bridge-production.up.railway.app');
  static const defaultBridgeToken = String.fromEnvironment('MZD_BRIDGE_TOKEN');

  String bridgeUrl = defaultBridgeUrl;
  String bridgeToken = defaultBridgeToken;
  late String deviceId;

  VehicleSource? _source;
  StreamSubscription<VehicleSnapshot>? _snapSub;
  StreamSubscription<SourceState>? _stateSub;
  VehicleSnapshot live = VehicleSnapshot.empty();
  SourceState sourceState = SourceState.disconnected;
  String? sourceError;
  List<String>? dtcs;
  DateTime? _lastSnapAt;
  DateTime _lastOdoSave = DateTime.now();

  VehicleSource? get source => _source;
  String get sourceName => _source?.name ?? (demoMode ? 'Modo demo' : 'Adaptador OBD-II');
  bool get connected => sourceState == SourceState.connected;

  AssistantClient get assistant => AssistantClient(baseUrl: bridgeUrl, token: bridgeToken.isEmpty ? null : bridgeToken, device: deviceId);

  // ---------------------------------------------------------------- persistence

  void _restore() {
    final p = _prefs.getString('profile');
    if (p != null) profile = CarProfile.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final m = _prefs.getString('maintenance');
    if (m != null) {
      final saved = {for (final e in (jsonDecode(m) as List)) (e['id'] as String): MaintenanceItem.fromJson(e as Map<String, dynamic>)};
      // keep new default items added in later versions
      maintenance = [...defaultSchedule().map((d) => saved.remove(d.id) ?? d), ...saved.values];
    }
    demoMode = _prefs.getBool('demoMode') ?? true;
    adapterId = _prefs.getString('adapterId');
    bridgeUrl = _prefs.getString('bridgeUrl') ?? bridgeUrl;
    bridgeToken = _prefs.getString('bridgeToken') ?? bridgeToken;
    deviceId = _prefs.getString('deviceId') ?? _newDeviceId();
    _prefs.setString('deviceId', deviceId);
  }

  static String _newDeviceId() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _save() async {
    await _prefs.setString('profile', jsonEncode(profile.toJson()));
    await _prefs.setString('maintenance', jsonEncode(maintenance.map((e) => e.toJson()).toList()));
    await _prefs.setBool('demoMode', demoMode);
    if (adapterId != null) await _prefs.setString('adapterId', adapterId!);
    await _prefs.setString('bridgeUrl', bridgeUrl);
    await _prefs.setString('bridgeToken', bridgeToken);
  }

  // ---------------------------------------------------------------- profile & settings

  Future<void> updateProfile(CarProfile p) async {
    profile = p;
    notifyListeners();
    await _save();
  }

  Future<void> updateBridge(String url, String token) async {
    bridgeUrl = url.trim();
    bridgeToken = token.trim();
    notifyListeners();
    await _save();
  }

  Future<void> setDemoMode(bool on) async {
    if (on == demoMode) return;
    await disconnect();
    demoMode = on;
    dtcs = null;
    notifyListeners();
    await _save();
  }

  // ---------------------------------------------------------------- live data

  Future<void> connect() async {
    await disconnect();
    final src = demoMode ? DemoSource() : BleObdSource(deviceId: adapterId);
    _source = src;
    _stateSub = src.states.listen((s) {
      sourceState = s;
      sourceError = src.lastError;
      if (src is BleObdSource && s == SourceState.connected && src.deviceId != adapterId) {
        adapterId = src.deviceId;
        _save();
      }
      notifyListeners();
    });
    _snapSub = src.snapshots.listen(_onSnapshot);
    await src.connect();
    // Check the engine's trouble codes right away, like glancing at the check-engine light.
    // (src.state, not sourceState: the state stream notifies listeners asynchronously.)
    if (src.state == SourceState.connected) {
      sourceState = SourceState.connected;
      try {
        await readDtcs();
      } catch (_) {}
    }
  }

  void _onSnapshot(VehicleSnapshot s) {
    final now = s.time;
    // Estimate distance from speed (the 2017 Mazda doesn't expose its odometer over OBD-II).
    // Demo data never touches the real odometer.
    if (!demoMode && _lastSnapAt != null && (s.speed ?? 0) > 0) {
      final dt = now.difference(_lastSnapAt!).inMilliseconds / 1000;
      if (dt > 0 && dt < 5) {
        profile = profile.copyWith(odometerKm: profile.odometerKm + s.speed! * dt / 3600);
        if (now.difference(_lastOdoSave).inSeconds > 30) {
          _lastOdoSave = now;
          _save();
        }
      }
    }
    _lastSnapAt = now;
    live = s;
    notifyListeners();
  }

  Future<void> disconnect() async {
    await _snapSub?.cancel();
    await _stateSub?.cancel();
    await _source?.disconnect();
    _source = null;
    _lastSnapAt = null;
    sourceState = SourceState.disconnected;
    live = VehicleSnapshot.empty();
    notifyListeners();
    await _save();
  }

  Future<List<String>> readDtcs() async {
    final s = _source;
    if (s == null || !connected) throw 'Conecta el carro primero';
    dtcs = await s.readDtcs();
    notifyListeners();
    return dtcs!;
  }

  // ---------------------------------------------------------------- maintenance

  DueStatus statusOf(MaintenanceItem i) => dueStatus(i, profile.odometerKm, DateTime.now());

  /// Items sorted by urgency (overdue first).
  List<MaintenanceItem> get maintenanceByUrgency {
    int rank(MaintenanceItem i) => switch (statusOf(i).level) {
          DueLevel.due => 0,
          DueLevel.soon => 1,
          DueLevel.ok => 2,
          DueLevel.unknown => 3,
        };
    return [...maintenance]..sort((a, b) => rank(a) - rank(b));
  }

  int get alertsCount => maintenance.where((i) => statusOf(i).level == DueLevel.due || statusOf(i).level == DueLevel.soon).length + (dtcs?.length ?? 0);

  Future<void> markDone(String id, {double? km, DateTime? date}) async {
    maintenance = [
      for (final i in maintenance) i.id == id ? i.markDone(km ?? profile.odometerKm, date ?? DateTime.now()) : i,
    ];
    notifyListeners();
    await _save();
  }

  Future<void> updateItem(MaintenanceItem item) async {
    maintenance = [for (final i in maintenance) i.id == item.id ? item : i];
    notifyListeners();
    await _save();
  }

  /// Prompt for the AI to explain trouble codes for this exact car.
  String dtcPrompt(List<String> codes) =>
      'Mi ${profile.model} ${profile.year} (gasolina) tiene estos códigos de falla OBD-II: ${codes.join(', ')}. '
      'Explícame qué significan, qué tan urgente es y qué debería revisar el taller.';
}
