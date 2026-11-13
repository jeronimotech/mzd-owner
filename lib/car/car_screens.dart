import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_carplay/flutter_carplay.dart';

import '../models/maintenance.dart';
import '../state/app_state.dart';
import '../ui/format.dart';

/// The app on the car's screen: CarPlay (iPhone) and Android Auto (Android).
///
/// Both platforms only allow native templates (lists, information panes) — no custom
/// drawing — and the CarPlay "driving task" category asks for refreshes no faster than
/// every ~10 s. Structure: root list → Tablero / Mantenimiento / Diagnóstico.
class CarScreens {
  CarScreens(this.state);

  final AppState state;
  static const refreshEvery = Duration(seconds: 10);

  Timer? _timer;

  // CarPlay
  FlutterCarplay? _carplay;
  CPListItem? _cpDash, _cpMaint, _cpDiag;
  CPInformationTemplate? _cpDashInfo;

  // Android Auto
  FlutterAndroidAuto? _aa;
  AAPaneTemplate? _aaDashPane;

  void start() {
    if (kIsWeb) return;
    if (Platform.isIOS) _startCarPlay();
    if (Platform.isAndroid) _startAndroidAuto();
    _timer = Timer.periodic(refreshEvery, (_) => _refresh());
  }

  void dispose() {
    _timer?.cancel();
    _carplay?.removeListenerOnConnectionChange();
    _carplay?.closeConnection();
    _aa?.removeListenerOnConnectionChange();
    _aa?.closeConnection();
  }

  // ---------------------------------------------------------------- content

  List<(String, String)> _dashboardRows() {
    final v = state.live;
    return [
      ('Velocidad', fmtNum(v.speed, unit: 'km/h')),
      ('RPM', fmtNum(v.rpm)),
      ('Temp. motor', fmtNum(v.coolantTemp, unit: '°C')),
      ('Batería', fmtNum(v.voltage, decimals: 1, unit: 'V')),
      ('Gasolina', fmtNum(v.fuelLevel, unit: '%')),
      ('Temp. exterior', fmtNum(v.ambientTemp, unit: '°C')),
      ('Odómetro (est.)', fmtKm(state.profile.odometerKm)),
    ];
  }

  String _dashSummary() => state.connected
      ? '${fmtNum(state.live.speed, unit: 'km/h')} · ${fmtNum(state.live.coolantTemp, unit: '°C')}'
      : 'Sin conexión con el carro';

  String _maintSummary() {
    final due = state.maintenance.where((i) => state.statusOf(i).level == DueLevel.due).length;
    final soon = state.maintenance.where((i) => state.statusOf(i).level == DueLevel.soon).length;
    if (due > 0) return '$due vencido${due > 1 ? 's' : ''}${soon > 0 ? ' · $soon pronto' : ''}';
    if (soon > 0) return '$soon pronto';
    return 'Todo al día';
  }

  String _diagSummary() {
    final c = state.dtcs;
    if (c == null) return state.connected ? 'Toca para leer códigos' : 'Conecta el carro';
    return c.isEmpty ? 'Sin códigos de falla' : '${c.length} código${c.length > 1 ? 's' : ''}: ${c.join(', ')}';
  }

  List<(String, String)> _maintRows() => [
        for (final i in state.maintenanceByUrgency.take(8))
          (i.title, _levelPrefix(state.statusOf(i).level) + state.statusOf(i).label),
      ];

  static String _levelPrefix(DueLevel l) => switch (l) {
        DueLevel.due => '⚠︎ ',
        DueLevel.soon => '• ',
        _ => '',
      };

  // ---------------------------------------------------------------- CarPlay

  void _startCarPlay() {
    _carplay = FlutterCarplay();
    _cpDash = CPListItem(text: 'Tablero', detailText: _dashSummary(), onPress: (done, _) async {
      try {
        _cpDashInfo = CPInformationTemplate(
          title: 'Tablero',
          layout: CPInformationTemplateLayout.twoColumn,
          informationItems: [for (final r in _dashboardRows()) CPInformationItem(title: r.$1, detail: r.$2)],
          actions: const [],
          onPop: () => _cpDashInfo = null,
        );
        await FlutterCarplay.push(template: _cpDashInfo!);
      } finally {
        done();
      }
    });
    _cpMaint = CPListItem(text: 'Mantenimiento', detailText: _maintSummary(), onPress: (done, _) async {
      try {
        await FlutterCarplay.push(
          template: CPListTemplate(title: 'Mantenimiento', sections: [
            CPListSection(items: [for (final r in _maintRows()) CPListItem(text: r.$1, detailText: r.$2)]),
          ]),
        );
      } finally {
        done();
      }
    });
    _cpDiag = CPListItem(text: 'Diagnóstico', detailText: _diagSummary(), onPress: (done, _) async {
      try {
        if (state.connected) await state.readDtcs();
        final codes = state.dtcs ?? const <String>[];
        await FlutterCarplay.push(
          template: CPInformationTemplate(
            title: 'Diagnóstico',
            layout: CPInformationTemplateLayout.leading,
            informationItems: codes.isEmpty
                ? [CPInformationItem(title: 'Códigos de falla', detail: state.connected ? 'Ninguno' : 'Conecta el carro')]
                : [for (final c in codes) CPInformationItem(title: c, detail: 'Pide la explicación en el celular')],
            actions: const [],
          ),
        );
      } catch (_) {
        // reading codes can fail if the adapter drops; the list detail shows the state
      } finally {
        done();
        _refresh();
      }
    });

    FlutterCarplay.setRootTemplate(
      rootTemplate: CPListTemplate(
        title: state.profile.name,
        sections: [CPListSection(items: [_cpDash!, _cpMaint!, _cpDiag!])],
        systemIcon: 'car.fill',
      ),
      animated: false,
    );
    _carplay!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _refresh();
    });
  }

  void _refreshCarPlay() {
    if (_carplay == null) return;
    if (FlutterCarplay.connectionStatus != ConnectionStatusTypes.connected.name) return;
    _cpDash?.setDetailText(_dashSummary());
    _cpMaint?.setDetailText(_maintSummary());
    _cpDiag?.setDetailText(_diagSummary());
    final info = _cpDashInfo;
    if (info != null) {
      _carplay!.updateInformationTemplateItems(
        elementId: info.uniqueId,
        items: [for (final r in _dashboardRows()) CPInformationItem(title: r.$1, detail: r.$2)],
      );
    }
  }

  // ---------------------------------------------------------------- Android Auto

  void _startAndroidAuto() {
    _aa = FlutterAndroidAuto();
    _aa!.addListenerOnConnectionChange((status) {
      // Android Auto builds templates against the live car context: (re)submit on connect.
      if (status == ConnectionStatusTypes.connected) FlutterAndroidAuto.setRootTemplate(template: _aaRoot());
    });
  }

  AAListTemplate _aaRoot() => AAListTemplate(
        title: state.profile.name,
        sections: [
          AAListSection(items: [
            AAListItem(
              title: 'Tablero',
              subtitle: _dashSummary(),
              isBrowsable: true,
              onPress: (done, _) async {
                try {
                  _aaDashPane = _aaPane();
                  await FlutterAndroidAuto.push(template: _aaDashPane!);
                } finally {
                  await done();
                }
              },
            ),
            AAListItem(
              title: 'Mantenimiento',
              subtitle: _maintSummary(),
              isBrowsable: true,
              onPress: (done, _) async {
                try {
                  await FlutterAndroidAuto.push(
                    template: AAListTemplate(title: 'Mantenimiento', sections: [
                      AAListSection(items: [for (final r in _maintRows()) AAListItem(title: r.$1, subtitle: r.$2)]),
                    ]),
                  );
                } finally {
                  await done();
                }
              },
            ),
            AAListItem(
              title: 'Diagnóstico',
              subtitle: _diagSummary(),
              isBrowsable: true,
              loadingMessage: 'Leyendo códigos…',
              onPress: (done, _) async {
                try {
                  if (state.connected) await state.readDtcs();
                  final codes = state.dtcs ?? const <String>[];
                  await FlutterAndroidAuto.push(
                    template: AAPaneTemplate(
                      title: 'Diagnóstico',
                      items: codes.isEmpty
                          ? [AAPaneItem(title: 'Códigos de falla', detail: state.connected ? 'Ninguno' : 'Conecta el carro')]
                          : [for (final c in codes) AAPaneItem(title: c, detail: 'Pide la explicación en el celular')],
                    ),
                  );
                } catch (_) {
                } finally {
                  await done();
                }
              },
            ),
          ]),
        ],
      );

  AAPaneTemplate _aaPane({String? id}) => AAPaneTemplate(
        id: id,
        title: 'Tablero',
        items: [for (final r in _dashboardRows().take(4)) AAPaneItem(title: r.$1, detail: r.$2)],
      );

  void _refreshAndroidAuto() {
    if (_aa == null) return;
    if (FlutterAndroidAuto.connectionStatus != ConnectionStatusTypes.connected.name) return;
    final pane = _aaDashPane;
    if (pane != null) {
      FlutterAndroidAuto.updatePaneTemplate(template: _aaPane(id: pane.uniqueId)).catchError((_) {
        _aaDashPane = null; // screen was closed
        return false;
      });
    }
  }

  void _refresh() {
    try {
      _refreshCarPlay();
      _refreshAndroidAuto();
    } catch (e) {
      debugPrint('car screens refresh failed: $e');
    }
  }
}
