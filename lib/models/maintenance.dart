/// A recurring maintenance task, due by distance and/or time (whichever comes first).
class MaintenanceItem {
  const MaintenanceItem({
    required this.id,
    required this.title,
    this.everyKm,
    this.everyMonths,
    this.lastKm,
    this.lastDate,
    this.note,
  });

  final String id;
  final String title;
  final int? everyKm;
  final int? everyMonths;
  final double? lastKm;
  final DateTime? lastDate;
  final String? note;

  MaintenanceItem markDone(double km, DateTime date) => MaintenanceItem(
        id: id,
        title: title,
        everyKm: everyKm,
        everyMonths: everyMonths,
        lastKm: km,
        lastDate: date,
        note: note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'everyKm': everyKm,
        'everyMonths': everyMonths,
        'lastKm': lastKm,
        'lastDate': lastDate?.toIso8601String(),
        'note': note,
      };

  factory MaintenanceItem.fromJson(Map<String, dynamic> j) => MaintenanceItem(
        id: j['id'] as String,
        title: j['title'] as String,
        everyKm: (j['everyKm'] as num?)?.toInt(),
        everyMonths: (j['everyMonths'] as num?)?.toInt(),
        lastKm: (j['lastKm'] as num?)?.toDouble(),
        lastDate: j['lastDate'] == null ? null : DateTime.tryParse(j['lastDate'] as String),
        note: j['note'] as String?,
      );
}

enum DueLevel { ok, soon, due, unknown }

class DueStatus {
  const DueStatus(this.level, {this.kmLeft, this.daysLeft});
  final DueLevel level;
  final double? kmLeft;
  final int? daysLeft;

  /// Short Spanish summary, e.g. "En 1.200 km" or "Vencido hace 15 días".
  String get label {
    if (level == DueLevel.unknown) return 'Registra el último servicio';
    final parts = <String>[];
    if (kmLeft != null) {
      parts.add(kmLeft! >= 0 ? 'en ${_km(kmLeft!)}' : 'pasado por ${_km(-kmLeft!)}');
    }
    if (daysLeft != null) {
      parts.add(daysLeft! >= 0 ? 'en ${_days(daysLeft!)}' : 'vencido hace ${_days(-daysLeft!)}');
    }
    final s = parts.join(' · ');
    return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
  }

  static String _km(double v) => '${v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')} km';
  static String _days(int d) => d >= 60 ? '${(d / 30).round()} meses' : d == 1 ? '1 día' : '$d días';
}

const soonKm = 1000.0;
const soonDays = 30;

DueStatus dueStatus(MaintenanceItem item, double odometerKm, DateTime now) {
  if (item.lastKm == null && item.lastDate == null) return const DueStatus(DueLevel.unknown);
  double? kmLeft;
  int? daysLeft;
  if (item.everyKm != null && item.lastKm != null) {
    kmLeft = item.lastKm! + item.everyKm! - odometerKm;
  }
  if (item.everyMonths != null && item.lastDate != null) {
    final d = item.lastDate!;
    final dueDate = DateTime(d.year, d.month + item.everyMonths!, d.day);
    daysLeft = dueDate.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
  final overdue = (kmLeft != null && kmLeft < 0) || (daysLeft != null && daysLeft < 0);
  final soon = (kmLeft != null && kmLeft <= soonKm) || (daysLeft != null && daysLeft <= soonDays);
  return DueStatus(overdue ? DueLevel.due : soon ? DueLevel.soon : DueLevel.ok, kmLeft: kmLeft, daysLeft: daysLeft);
}

/// Suggested schedule for a gasoline SkyActiv Mazda in Colombia. Intervals are editable
/// starting points — the owner's manual and the dealer have the final word.
List<MaintenanceItem> defaultSchedule() => const [
      MaintenanceItem(id: 'oil', title: 'Aceite y filtro de aceite', everyKm: 10000, everyMonths: 12),
      MaintenanceItem(id: 'tires', title: 'Rotación y presión de llantas', everyKm: 10000, everyMonths: 6),
      MaintenanceItem(id: 'cabin', title: 'Filtro de cabina (aire acondicionado)', everyKm: 20000, everyMonths: 12),
      MaintenanceItem(id: 'air', title: 'Filtro de aire del motor', everyKm: 40000, everyMonths: 24),
      MaintenanceItem(id: 'brakes', title: 'Líquido de frenos', everyKm: 40000, everyMonths: 24),
      MaintenanceItem(id: 'plugs', title: 'Bujías', everyKm: 120000),
      MaintenanceItem(id: 'coolant', title: 'Refrigerante', everyKm: 160000, everyMonths: 120),
      MaintenanceItem(id: 'soat', title: 'SOAT', everyMonths: 12),
      MaintenanceItem(id: 'rtm', title: 'Revisión técnico-mecánica', everyMonths: 12),
    ];
