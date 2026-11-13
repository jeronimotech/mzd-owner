import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import '../models/vehicle.dart';
import 'elm327.dart';
import 'vehicle_source.dart';

/// ELM327-compatible OBD-II adapter over Bluetooth LE (Vgate iCar Pro BLE, Veepeak BLE+,
/// OBDLink CX, most "BLE" clones). Bluetooth Classic adapters don't work on iPhone.
class BleObdSource implements VehicleSource {
  BleObdSource({this.deviceId});

  /// Remembered adapter; when null we scan for the first adapter that looks like an OBD dongle.
  String? deviceId;
  String? _deviceName;

  static const _nameHints = ['OBD', 'VGATE', 'ICAR', 'VEEPEAK', 'VLINK', 'V-LINK', 'ELM', 'KONNWEI'];

  static bool looksLikeObd(BleDevice d) {
    final n = (d.name ?? '').toUpperCase();
    return n.isNotEmpty && _nameHints.any(n.contains);
  }

  final _snap = StreamController<VehicleSnapshot>.broadcast();
  final _state = StreamController<SourceState>.broadcast();
  SourceState _current = SourceState.disconnected;
  String? _error;
  String? _service, _txChar;
  bool _txWithoutResponse = false;
  StreamSubscription<Uint8List>? _rxSub;
  StreamSubscription<bool>? _connSub;
  final _buffer = StringBuffer();
  Completer<String>? _pending;
  bool _polling = false;
  VehicleSnapshot _last = VehicleSnapshot.empty();
  final Map<String, int> _misses = {};

  @override
  String get name => _deviceName ?? 'Adaptador OBD-II';
  @override
  Stream<VehicleSnapshot> get snapshots => _snap.stream;
  @override
  Stream<SourceState> get states => _state.stream;
  @override
  SourceState get state => _current;
  @override
  String? get lastError => _error;

  void _set(SourceState s, [String? error]) {
    _current = s;
    _error = error;
    _state.add(s);
  }

  @override
  Future<void> connect() async {
    _set(SourceState.connecting);
    try {
      final availability = await UniversalBle.getBluetoothAvailabilityState();
      if (availability == AvailabilityState.poweredOff) throw 'Bluetooth está apagado';
      if (availability == AvailabilityState.unauthorized) throw 'La app no tiene permiso de Bluetooth';
      if (!await UniversalBle.hasPermissions()) await UniversalBle.requestPermissions();

      final id = deviceId ?? await _findAdapter();
      if (id == null) throw 'No encontré un adaptador OBD-II cerca. Conéctalo al carro y enciende el motor.';
      await UniversalBle.connect(id, timeout: const Duration(seconds: 15));
      deviceId = id;
      await _pickCharacteristics(id);
      for (final cmd in elmInitCommands) {
        await _send(cmd, timeout: cmd == 'ATZ' ? const Duration(seconds: 3) : const Duration(seconds: 2));
      }
      _set(SourceState.connected);
      _connSub = UniversalBle.connectionStream(id).listen((connected) {
        if (!connected && _current == SourceState.connected) {
          _polling = false;
          _set(SourceState.disconnected, 'Se perdió la conexión con el adaptador');
        }
      });
      _poll();
    } catch (e) {
      _set(SourceState.error, e.toString());
      await _cleanup();
    }
  }

  Future<String?> _findAdapter() async {
    final found = Completer<String?>();
    final sub = UniversalBle.scanStream.listen((d) {
      if (looksLikeObd(d) && !found.isCompleted) {
        _deviceName = d.name;
        found.complete(d.deviceId);
      }
    });
    await UniversalBle.startScan();
    final id = await found.future.timeout(const Duration(seconds: 10), onTimeout: () => null);
    await sub.cancel();
    await UniversalBle.stopScan();
    return id;
  }

  /// ELM327 BLE adapters expose a serial-like service: a notify characteristic for replies
  /// and a write characteristic for commands (often FFF1/FFF2, or a single FFE1).
  Future<void> _pickCharacteristics(String id) async {
    final services = await UniversalBle.discoverServices(id);
    services.sort((a, b) => _score(b.uuid) - _score(a.uuid));
    for (final s in services) {
      BleCharacteristic? rx, tx;
      for (final c in s.characteristics) {
        final p = c.properties;
        if (rx == null && (p.contains(CharacteristicProperty.notify) || p.contains(CharacteristicProperty.indicate))) rx = c;
        if (tx == null && (p.contains(CharacteristicProperty.write) || p.contains(CharacteristicProperty.writeWithoutResponse))) tx = c;
      }
      if (rx != null && tx != null) {
        _service = s.uuid;
        _txChar = tx.uuid;
        _txWithoutResponse = !tx.properties.contains(CharacteristicProperty.write);
        _rxSub = UniversalBle.characteristicValueStream(id, rx.uuid).listen(_onData);
        if (rx.properties.contains(CharacteristicProperty.notify)) {
          await UniversalBle.subscribeNotifications(id, s.uuid, rx.uuid);
        } else {
          await UniversalBle.subscribeIndications(id, s.uuid, rx.uuid);
        }
        return;
      }
    }
    throw 'Este dispositivo no parece un adaptador OBD-II BLE compatible';
  }

  static int _score(String uuid) {
    final u = uuid.toLowerCase();
    if (u.contains('fff0')) return 3;
    if (u.contains('ffe0')) return 2;
    if (u.startsWith('000018f0') || u.startsWith('e7810a71')) return 1;
    return 0;
  }

  void _onData(Uint8List bytes) {
    _buffer.write(ascii.decode(bytes, allowInvalid: true));
    if (_buffer.toString().contains('>')) {
      final reply = _buffer.toString();
      _buffer.clear();
      final p = _pending;
      _pending = null;
      if (p != null && !p.isCompleted) p.complete(reply);
    }
  }

  Future<String> _send(String command, {Duration timeout = const Duration(seconds: 2)}) async {
    final id = deviceId, service = _service, tx = _txChar;
    if (id == null || service == null || tx == null) throw 'Adaptador no conectado';
    _buffer.clear();
    final c = Completer<String>();
    _pending = c;
    await UniversalBle.write(id, service, tx, Uint8List.fromList(ascii.encode('$command\r')), withoutResponse: _txWithoutResponse);
    return c.future.timeout(timeout, onTimeout: () {
      _pending = null;
      return 'NO DATA';
    });
  }

  Future<void> _poll() async {
    if (_polling) return;
    _polling = true;
    while (_polling && _current == SourceState.connected) {
      for (final pid in pids) {
        if (!_polling) break;
        if ((_misses[pid.code] ?? 0) >= 3) continue; // the car doesn't report this one
        final raw = await _send(pid.command);
        final v = parsePid(pid, raw);
        if (v == null) {
          _misses[pid.code] = (_misses[pid.code] ?? 0) + 1;
          continue;
        }
        _misses[pid.code] = 0;
        _last = _last.withValue(pid.key, v);
        _snap.add(_last);
      }
    }
  }

  @override
  Future<List<String>> readDtcs() async {
    if (_current != SourceState.connected) return const [];
    final wasPolling = _polling;
    _polling = false;
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final raw = await _send('03', timeout: const Duration(seconds: 4));
    if (wasPolling) _poll();
    return parseDtcs(raw);
  }

  Future<void> _cleanup() async {
    _polling = false;
    await _rxSub?.cancel();
    await _connSub?.cancel();
    _rxSub = null;
    _connSub = null;
    _service = _txChar = null;
    final id = deviceId;
    if (id != null) {
      try {
        await UniversalBle.disconnect(id);
      } catch (_) {}
    }
  }

  @override
  Future<void> disconnect() async {
    await _cleanup();
    _set(SourceState.disconnected);
  }
}
