import 'package:flutter/material.dart';

/// The paper milk card on the fridge: cream card, teal ink, a red pen for
/// days it did not come and a circle for extra.
class Look {
  const Look._({
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.pen,
    required this.extra,
  });

  final Color paper, card, ink, muted, grid, pen, extra;

  static const light = Look._(
    paper: Color(0xFFE9EEEC),
    card: Color(0xFFFCF8EE),
    ink: Color(0xFF12454D),
    muted: Color(0xFF6C7A78),
    grid: Color(0xFFE2D9C4),
    pen: Color(0xFFC0392B),
    extra: Color(0xFF1E7B4F),
  );

  static const dark = Look._(
    paper: Color(0xFF0F1716),
    card: Color(0xFF1A2322),
    ink: Color(0xFFCFE7E4),
    muted: Color(0xFF8EA19E),
    grid: Color(0xFF2E3B39),
    pen: Color(0xFFF07A6C),
    extra: Color(0xFF5CCB93),
  );

  static Look of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;

  static const figures = [FontFeature.tabularFigures()];

  TextStyle label() => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: muted,
  );

  ThemeData theme(Brightness b) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: grid),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme(
        brightness: b,
        primary: ink,
        onPrimary: card,
        secondary: extra,
        onSecondary: Colors.white,
        error: pen,
        onError: Colors.white,
        surface: card,
        onSurface: ink,
        errorContainer: pen.withValues(alpha: 0.14),
        tertiaryContainer: extra.withValues(alpha: 0.16),
        surfaceContainerHighest: grid.withValues(alpha: 0.5),
      ),
      scaffoldBackgroundColor: paper,
      dividerColor: grid,
      appBarTheme: AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        filled: true,
        fillColor: card,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: card,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          side: BorderSide(color: grid),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: ink),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// One day on the card: the quantity in ink, a red strike if it did not
/// come, a circle if it came extra.
class DayMark extends StatelessWidget {
  const DayMark({
    super.key,
    required this.day,
    required this.qty,
    required this.usual,
    required this.active,
    this.big = false,
  });

  final int day;
  final double qty;
  final double usual;

  /// False for days before the start date or after today.
  final bool active;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final l = Look.of(context);
    final skipped = active && qty == 0;
    final extra = active && qty > usual;
    String q(double v) =>
        v == v.roundToDouble() ? v.toInt().toString() : v.toString();
    return CustomPaint(
      painter: _Marks(
        skipped: skipped,
        extra: extra,
        pen: l.pen,
        green: l.extra,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontSize: big ? 11 : 8.5,
              color: l.muted,
              height: 1,
              fontFeatures: Look.figures,
            ),
          ),
          if (active)
            Text(
              skipped ? '' : q(qty),
              style: TextStyle(
                fontSize: big ? 16 : 11.5,
                fontWeight: FontWeight.w700,
                color: extra ? l.extra : l.ink,
                height: 1.15,
                fontFeatures: Look.figures,
              ),
            )
          else
            SizedBox(height: big ? 18 : 13),
        ],
      ),
    );
  }
}

class _Marks extends CustomPainter {
  _Marks({
    required this.skipped,
    required this.extra,
    required this.pen,
    required this.green,
  });
  final bool skipped, extra;
  final Color pen, green;

  @override
  void paint(Canvas canvas, Size s) {
    if (skipped) {
      final p = Paint()
        ..color = pen
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(s.width * 0.25, s.height * 0.78),
        Offset(s.width * 0.75, s.height * 0.32),
        p,
      );
    }
    if (extra) {
      final p = Paint()
        ..color = green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawOval(
        Rect.fromCenter(
          center: s.center(Offset.zero),
          width: s.width * 0.82,
          height: s.height * 0.86,
        ),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_Marks o) =>
      o.skipped != skipped || o.extra != extra || o.pen != pen;
}
