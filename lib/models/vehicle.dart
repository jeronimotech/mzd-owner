/// One reading of the car's live data. Any field may be null when the car doesn't report it.
class VehicleSnapshot {
  const VehicleSnapshot({
    this.speed,
    this.rpm,
    this.coolantTemp,
    this.intakeTemp,
    this.engineLoad,
    this.throttle,
    this.fuelLevel,
    this.voltage,
    this.ambientTemp,
    required this.time,
  });

  final double? speed; // km/h
  final double? rpm;
  final double? coolantTemp; // °C
  final double? intakeTemp; // °C
  final double? engineLoad; // %
  final double? throttle; // %
  final double? fuelLevel; // %
  final double? voltage; // V
  final double? ambientTemp; // °C
  final DateTime time;

  static VehicleSnapshot empty() => VehicleSnapshot(time: DateTime.now());

  VehicleSnapshot withValue(String key, double? v) => VehicleSnapshot(
        speed: key == 'speed' ? v : speed,
        rpm: key == 'rpm' ? v : rpm,
        coolantTemp: key == 'coolantTemp' ? v : coolantTemp,
        intakeTemp: key == 'intakeTemp' ? v : intakeTemp,
        engineLoad: key == 'engineLoad' ? v : engineLoad,
        throttle: key == 'throttle' ? v : throttle,
        fuelLevel: key == 'fuelLevel' ? v : fuelLevel,
        voltage: key == 'voltage' ? v : voltage,
        ambientTemp: key == 'ambientTemp' ? v : ambientTemp,
        time: DateTime.now(),
      );

  bool get engineRunning => (rpm ?? 0) > 300;
}

/// The owner's car.
class CarProfile {
  const CarProfile({
    this.name = 'Mi Mazda',
    this.model = 'Mazda 3',
    this.year = 2017,
    this.plate = '',
    this.odometerKm = 0,
  });

  final String name;
  final String model;
  final int year;
  final String plate;
  final double odometerKm;

  /// Last digit of the plate (useful for pico y placa questions).
  String? get plateLastDigit {
    final digits = plate.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : digits[digits.length - 1];
  }

  CarProfile copyWith({String? name, String? model, int? year, String? plate, double? odometerKm}) => CarProfile(
        name: name ?? this.name,
        model: model ?? this.model,
        year: year ?? this.year,
        plate: plate ?? this.plate,
        odometerKm: odometerKm ?? this.odometerKm,
      );

  Map<String, dynamic> toJson() => {'name': name, 'model': model, 'year': year, 'plate': plate, 'odometerKm': odometerKm};

  factory CarProfile.fromJson(Map<String, dynamic> j) => CarProfile(
        name: j['name'] as String? ?? 'Mi Mazda',
        model: j['model'] as String? ?? 'Mazda 3',
        year: (j['year'] as num?)?.toInt() ?? 2017,
        plate: j['plate'] as String? ?? '',
        odometerKm: (j['odometerKm'] as num?)?.toDouble() ?? 0,
      );
}
