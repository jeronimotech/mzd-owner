/// Display helpers shared by the phone UI and the car screens.
String fmtNum(double? v, {int decimals = 0, String unit = '', String placeholder = '--'}) {
  if (v == null || v.isNaN) return placeholder;
  final s = v.toStringAsFixed(decimals);
  final parts = s.split('.');
  final grouped = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  final out = parts.length > 1 ? '$grouped,${parts[1]}' : grouped;
  return unit.isEmpty ? out : '$out $unit';
}

String fmtKm(double km) => fmtNum(km, unit: 'km');

String fmtDate(DateTime d) {
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
