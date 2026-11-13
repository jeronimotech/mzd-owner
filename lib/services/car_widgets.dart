import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/maintenance.dart';
import '../state/app_state.dart';

/// Feeds the iOS widget ("Estado de mi carro") and the drive Live Activity, which iOS 26
/// also shows on the CarPlay dashboard. No-op on other platforms.
class CarWidgets {
  CarWidgets(this.state);

  final AppState state;
  static const _channel = MethodChannel('mzd/car_widgets');

  static const statusEvery = Duration(seconds: 60);
  static const driveEvery = Duration(seconds: 3);

  DateTime _lastStatus = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastDrive = DateTime.fromMillisecondsSinceEpoch(0);
  String _lastStatusKey = '';
  bool _driving = false;

  void start() {
    if (kIsWeb || !Platform.isIOS) return;
    state.addListener(_onChange);
    _onChange();
  }

  void _onChange() {
    final now = DateTime.now();
    final status = _statusPayload();
    // Push the widget when something meaningful changed, or at most once a minute for live values.
    final key = '${status['connected']}|${status['serviceTitle']}|${status['serviceLevel']}|${status['dtcCount']}';
    if (key != _lastStatusKey || now.difference(_lastStatus) >= statusEvery) {
      _lastStatusKey = key;
      _lastStatus = now;
      _call('updateStatus', status);
    }

    if (state.connected) {
      if (!_driving) {
        _driving = true;
        _lastDrive = now;
        _call('startDrive', _drivePayload());
      } else if (now.difference(_lastDrive) >= driveEvery) {
        _lastDrive = now;
        _call('updateDrive', _drivePayload());
      }
    } else if (_driving) {
      _driving = false;
      _call('endDrive', const {});
    }
  }

  Map<String, Object?> _statusPayload() {
    final next = state.maintenanceByUrgency.isEmpty ? null : state.maintenanceByUrgency.first;
    final st = next == null ? null : state.statusOf(next);
    return {
      'carName': state.profile.name,
      'connected': state.connected,
      'coolant': state.live.coolantTemp,
      'voltage': state.live.voltage,
      'fuel': state.live.fuelLevel,
      'serviceTitle': next?.title,
      'serviceLabel': st?.label,
      'serviceLevel': switch (st?.level) {
        DueLevel.due => 'due',
        DueLevel.soon => 'soon',
        DueLevel.ok => 'ok',
        _ => 'unknown',
      },
      'dtcCount': state.dtcs?.length,
    };
  }

  Map<String, Object?> _drivePayload() {
    final v = state.live;
    String? warning;
    if ((v.coolantTemp ?? 0) > 105) {
      warning = 'Motor caliente';
    } else if (v.voltage != null && v.voltage! < 12) {
      warning = 'Revisa la batería';
    } else if (state.dtcs?.isNotEmpty ?? false) {
      warning = 'Código de falla';
    }
    return {
      'carName': state.profile.name,
      'speed': v.speed,
      'rpm': v.rpm,
      'coolant': v.coolantTemp,
      'voltage': v.voltage,
      'warning': warning,
    };
  }

  Future<void> _call(String method, Map<String, Object?> args) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException catch (e) {
      debugPrint('car widgets $method failed: ${e.message}');
    } on MissingPluginException {
      // running without the native side (tests, other platforms)
    }
  }
}
