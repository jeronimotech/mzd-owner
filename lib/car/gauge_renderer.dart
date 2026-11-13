import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Renders gauge "cards" as PNG images for CarPlay / Android Auto.
///
/// Car platforms only allow native templates, but templates accept images — so the look of
/// the phone dashboard (arc gauge, big number, Soul Red) is drawn here and shipped as artwork.
class GaugeRenderer {
  GaugeRenderer({this.width = 360, this.height = 360});

  final int width;
  final int height;

  static const soulRed = ui.Color(0xFFC8102E);
  static const warnColor = ui.Color(0xFFFFA726);

  /// Draws one gauge and returns PNG bytes. Bytes (not files) are sent to the car host:
  /// the native side applies them synchronously when it builds the element, while a file
  /// would load after the element is already on screen and never show up.
  Future<Uint8List> render({
    required String value,
    required String label,
    required double fraction,
    bool warn = false,
    bool live = true,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final w = width.toDouble(), h = height.toDouble();

    // Transparent background: the gauge sits directly on CarPlay's own card material,
    // so there's no box-in-a-box and it matches light and dark car themes.
    final center = ui.Offset(w / 2, h * 0.53);
    final radius = w * 0.42;
    final rect = ui.Rect.fromCircle(center: center, radius: radius);
    const start = pi * 0.8, sweep = pi * 1.4;
    const stroke = 30.0;
    final track = ui.Paint()
      ..color = const ui.Color(0x33FFFFFF)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = ui.StrokeCap.round;
    canvas.drawArc(rect, start, sweep, false, track);
    final f = live ? fraction.clamp(0.0, 1.0) : 0.0;
    if (f > 0.005) {
      final accent = warn ? warnColor : soulRed;
      final fg = ui.Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [accent.withValues(alpha: 0.65), accent, warn ? warnColor : const ui.Color(0xFFFF3B55)],
          const [0.0, 0.6, 1.0],
          ui.TileMode.clamp,
          start,
          start + sweep,
        )
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = ui.StrokeCap.round;
      canvas.drawArc(rect, start, sweep * f, false, fg);
    }

    _text(canvas, live ? value : '--', w, center.dy - 66, 104, ui.FontWeight.w800, const ui.Color(0xFFFFFFFF));
    _text(canvas, label.toUpperCase(), w, center.dy + 50, 30, ui.FontWeight.w700,
        warn ? warnColor : const ui.Color(0xCCFFFFFF), letterSpacing: 3);

    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
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
