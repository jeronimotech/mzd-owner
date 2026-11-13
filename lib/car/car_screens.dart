import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_carplay/flutter_carplay.dart';

import '../models/maintenance.dart';
import '../models/vehicle.dart';
import '../state/app_state.dart';
import '../ui/format.dart';
import 'gauge_renderer.dart';

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

  final _gauges = GaugeRenderer();

  // CarPlay
  FlutterCarplay? _carplay;
  CPListImageRowItem? _cpGauges;
  List<CPListItem> _cpMaintRows = [];
  CPListItem? _cpDiag;
  CPInformationTemplate? _cpDashInfo;
  bool _rendering = false;

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

  // ---------------------------------------------------------------- gauges (artwork)

  /// The four gauges shown as cards: (key, value, label, fraction, warn).
  List<(String, String, String, double, bool)> _gaugeSpecs(VehicleSnapshot v) => [
        ('speed', fmtNum(v.speed), 'km/h', (v.speed ?? 0) / 180, false),
        ('rpm', fmtNum(v.rpm), 'rpm', (v.rpm ?? 0) / 7000, (v.rpm ?? 0) > 6000),
        ('coolant', fmtNum(v.coolantTemp, unit: '°'), 'motor', ((v.coolantTemp ?? 0) - 20) / 100, (v.coolantTemp ?? 0) > 105),
        ('battery', fmtNum(v.voltage, decimals: 1), 'batería V', ((v.voltage ?? 11) - 11) / 4,
            v.voltage != null && (v.voltage! < 12 || v.voltage! > 15)),
      ];

  int _gaugeVersion = 0;

  Future<List<CPListImageRowItemCardElement>> _gaugeCards() async {
    final live = state.connected;
    final version = ++_gaugeVersion;
    final cards = <CPListImageRowItemCardElement>[];
    for (final g in _gaugeSpecs(state.live)) {
      final png = await _gauges.render(value: g.$2, label: g.$3, fraction: g.$4, warn: g.$5, live: live);
      cards.add(_PngCardElement(png: png, image: 'mzd-gauge-${g.$1}-$version'));
    }
    return cards;
  }

  String _liveLabel() => switch (state.sourceState.name) {
        'connected' => 'En vivo · ${state.sourceName}',
        'connecting' => 'Conectando…',
        _ => 'Sin conexión · abre la app en el celular',
      };

  // ---------------------------------------------------------------- CarPlay

  static const _redTint = AutoImageTint.custom(color: UIColor(red: 230, green: 40, blue: 60), darkColor: UIColor(red: 255, green: 90, blue: 105));
  static const _amberTint = AutoImageTint.custom(color: UIColor(red: 230, green: 140, blue: 20), darkColor: UIColor(red: 255, green: 180, blue: 70));
  static const _greenTint = AutoImageTint.custom(color: UIColor(red: 30, green: 160, blue: 90), darkColor: UIColor(red: 60, green: 215, blue: 130));
  static const _greyTint = AutoImageTint.platform();

  AutoImageTint _tintFor(DueLevel l) => switch (l) {
        DueLevel.due => _redTint,
        DueLevel.soon => _amberTint,
        DueLevel.ok => _greenTint,
        DueLevel.unknown => _greyTint,
      };

  List<CPListItem> _maintItems() {
    final urgent = state.maintenanceByUrgency.take(3).toList();
    return [
      for (final i in urgent)
        CPListItem(
          text: i.title,
          detailText: state.statusOf(i).label,
          image: state.statusOf(i).level == DueLevel.due ? 'assets/car/alert.svg' : 'assets/car/wrench.svg',
          imageTint: _tintFor(state.statusOf(i).level),
        ),
      CPListItem(
        text: 'Ver todo el mantenimiento',
        image: 'assets/car/list.svg',
        imageTint: _greyTint,
        accessoryType: CPListItemAccessoryType.disclosureIndicator,
        onPress: (done, _) async {
          try {
            await FlutterCarplay.push(
              template: CPListTemplate(title: 'Mantenimiento', sections: [
                CPListSection(items: [
                  for (final i in state.maintenanceByUrgency)
                    CPListItem(
                      text: i.title,
                      detailText: state.statusOf(i).label,
                      image: 'assets/car/wrench.svg',
                      imageTint: _tintFor(state.statusOf(i).level),
                    ),
                ]),
              ]),
            );
          } finally {
            done();
          }
        },
      ),
    ];
  }

  AutoImageTint _diagTint() {
    final c = state.dtcs;
    if (c == null) return _greyTint;
    return c.isEmpty ? _greenTint : _amberTint;
  }

  Future<void> _openDashboard() async {
    _cpDashInfo = CPInformationTemplate(
      title: 'Tablero',
      layout: CPInformationTemplateLayout.twoColumn,
      informationItems: [for (final r in _dashboardRows()) CPInformationItem(title: r.$1, detail: r.$2)],
      actions: const [],
      onPop: () => _cpDashInfo = null,
    );
    await FlutterCarplay.push(template: _cpDashInfo!);
  }

  Future<void> _startCarPlay() async {
    _carplay = FlutterCarplay();
    FlutterCarplay.iconSize = const AutoImageSize.medium();

    final cards = await _gaugeCards();
    _cpGauges = CPListImageRowItem(
      text: _liveLabel(),
      elements: cards,
      onPress: (done, _) async {
        try {
          await _openDashboard();
        } finally {
          done();
        }
      },
      onItemPress: (done, _, _) async {
        try {
          await _openDashboard();
        } finally {
          done();
        }
      },
    );
    _cpMaintRows = _maintItems();
    _cpDiag = CPListItem(
      text: 'Códigos de falla',
      detailText: _diagSummary(),
      image: 'assets/car/shield.svg',
      imageTint: _diagTint(),
      accessoryType: CPListItemAccessoryType.disclosureIndicator,
      onPress: (done, item) async {
        try {
          if (state.connected) await state.readDtcs();
          final codes = state.dtcs ?? const <String>[];
          item.setDetailText(_diagSummary());
          await FlutterCarplay.push(
            template: CPListTemplate(
              title: 'Diagnóstico',
              sections: [
                CPListSection(items: [
                  if (codes.isEmpty)
                    CPListItem(
                      text: state.connected ? 'Sin códigos de falla' : 'Conecta el carro',
                      image: 'assets/car/shield.svg',
                      imageTint: state.connected ? _greenTint : _greyTint,
                    ),
                  for (final c in codes)
                    CPListItem(text: c, detailText: 'Pide la explicación en el celular', image: 'assets/car/alert.svg', imageTint: _amberTint),
                ]),
              ],
            ),
          );
        } catch (_) {
          // reading codes can fail if the adapter drops; the row detail shows the state
        } finally {
          done();
        }
      },
    );

    await FlutterCarplay.setRootTemplate(
      rootTemplate: CPListTemplate(
        title: state.profile.name,
        sections: [
          CPListSection(items: [_cpGauges!]),
          CPListSection(header: 'Mantenimiento', items: _cpMaintRows),
          CPListSection(header: 'Diagnóstico', items: [_cpDiag!]),
        ],
        systemIcon: 'car.fill',
      ),
      animated: false,
    );
    _carplay!.addListenerOnConnectionChange((status) {
      if (status == ConnectionStatusTypes.connected) _refresh();
    });
  }

  Future<void> _refreshCarPlay() async {
    if (_carplay == null || _cpGauges == null) return;
    if (FlutterCarplay.connectionStatus != ConnectionStatusTypes.connected.name) return;
    if (_rendering) return;
    _rendering = true;
    try {
      _cpGauges!.setElements(await _gaugeCards());
      _cpGauges!.setText(_liveLabel());
      final urgent = state.maintenanceByUrgency.take(3).toList();
      for (var i = 0; i < urgent.length && i < _cpMaintRows.length - 1; i++) {
        _cpMaintRows[i].setText(urgent[i].title);
        _cpMaintRows[i].setDetailText(state.statusOf(urgent[i]).label);
        _cpMaintRows[i].setImageTint(_tintFor(state.statusOf(urgent[i]).level));
      }
      _cpDiag?.setDetailText(_diagSummary());
      _cpDiag?.setImageTint(_diagTint());
      final info = _cpDashInfo;
      if (info != null) {
        await _carplay!.updateInformationTemplateItems(
          elementId: info.uniqueId,
          items: [for (final r in _dashboardRows()) CPInformationItem(title: r.$1, detail: r.$2)],
        );
      }
    } finally {
      _rendering = false;
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

/// Card element that carries its artwork as PNG bytes (`imageData`), which the native side
/// applies synchronously. [image] is only an identifier for the native image cache.
class _PngCardElement extends CPListImageRowItemCardElement {
  // Full slot size, no title: the label is drawn inside the gauge.
  _PngCardElement({required this.png, required super.image})
      : super(showsImageFullHeight: true, imageSize: const AutoImageSize.max());

  final Uint8List png;

  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'imageData': png};
}
