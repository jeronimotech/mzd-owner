import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

/// Renders gauge "cards" as PNG files for CarPlay / Android Auto.
///
/// Car platforms only allow native templates, but templates accept images — so the look of
/// the phone dashboard (arc gauge, big number, Soul Red) is drawn here and shipped as artwork.
class GaugeRenderer {
  GaugeRenderer({this.width = 420, this.height = 300});

  final int width;
  final int height;
  int _version = 0;
  final Map<String, String> _lastFile = {};

  static const soulRed = ui.Color(0xFFC8102E);
  static const warnColor = ui.Color(0xFFFFA726);

  /// Draws one gauge and returns a `file://` URL. A new file per version so the car host
  /// doesn't serve a cached image; the previous file for the same [key] is deleted.
  Future<String> render({
    required String key,
    required String value,
    required String unit,
    required double fraction,
    bool warn = false,
    bool live = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final w = width.toDouble(), h = height.toDouble();

    // card background
    final bg = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(w, h),
        [const ui.Color(0xFF24262C), const ui.Color(0xFF111215)],
      );
    canvas.drawRRect(ui.RRect.fromRectAndRadius(ui.Rect.fromLTWH(0, 0, w, h), const ui.Radius.circular(36)), bg);

    // arc
    final center = ui.Offset(w / 2, h * 0.64);
    final radius = min(w * 0.40, h * 0.52);
    final rect = ui.Rect.fromCircle(center: center, radius: radius);
    const start = pi * 0.85, sweep = pi * 1.3;
    final track = ui.Paint()
      ..color = const ui.Color(0xFF34373E)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, track);
    final f = live ? fraction.clamp(0.0, 1.0) : 0.0;
    if (f > 0.005) {
      final accent = warn ? warnColor : soulRed;
      final fg = ui.Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [accent.withValues(alpha: 0.55), accent],
          null,
          ui.TileMode.clamp,
          start,
          start + sweep,
        )
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = ui.StrokeCap.round;
      canvas.drawArc(rect, start, sweep * f, false, fg);
    }

    // value + unit
    _text(canvas, live ? value : '--', w, center.dy - 62, 92, ui.FontWeight.w800, const ui.Color(0xFFFFFFFF));
    _text(canvas, unit.toUpperCase(), w, center.dy + 38, 30, ui.FontWeight.w600,
        warn ? warnColor : const ui.Color(0xB3FFFFFF), letterSpacing: 4);

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('${Directory.systemTemp.path}/mzd_car');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final file = File('${dir.path}/${key}_${++_version}.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    final old = _lastFile[key];
    _lastFile[key] = file.path;
    if (old != null) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
    return file.uri.toString();
  }

  void _text(ui.Canvas canvas, String text, double w, double top, double size, ui.FontWeight weight, ui.Color color,
      {double letterSpacing = 0}) {
    final b = ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center, maxLines: 1))
      ..pushStyle(ui.TextStyle(color: color, fontSize: size, fontWeight: weight, letterSpacing: letterSpacing))
      ..addText(text);
    final p = b.build()..layout(ui.ParagraphConstraints(width: w));
    canvas.drawParagraph(p, ui.Offset(0, top));
  }
}
