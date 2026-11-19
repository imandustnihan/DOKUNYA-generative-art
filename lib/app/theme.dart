import 'package:material_ui/material_ui.dart';

const ink = Color(0xff0b0c12),
    surface = Color(0xff15161f),
    line = Color(0xff282934),
    muted = Color(0xff9494aa),
    accent = Color(0xffbc9aff);
ThemeData artTheme({bool tv = false}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        surface: surface,
        primary: accent,
        onPrimary: const Color(0xff20143a),
        onSurface: const Color(0xffeeedf5),
        outline: line,
      );
  return ThemeData(
    useMaterial3: true,
    fontFamily: "NotoSans",
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ink,
    textTheme: ThemeData.dark().textTheme.apply(
      fontFamily: 'NotoSans',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    dividerColor: line,
    focusColor: accent.withValues(alpha: .25),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: muted,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: line),
      ),
    ),
    sliderTheme: const SliderThemeData(
      trackHeight: 3,
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      overlayShape: RoundSliderOverlayShape(overlayRadius: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ink,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: line),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class ArtMark extends StatelessWidget {
  const ArtMark({super.key, this.size = 36});
  final double size;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: _MarkPainter());
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .09
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(size.width * .18, size.height * .72);
    path.cubicTo(
      size.width * .27,
      -size.height * .02,
      size.width * .67,
      -size.height * .02,
      size.width * .8,
      size.height * .6,
    );
    path.cubicTo(
      size.width * .92,
      size.height * 1.03,
      size.width * .37,
      size.height * .93,
      size.width * .39,
      size.height * .53,
    );
    p.shader = const LinearGradient(colors: [accent, Color(0xff71e5f5)])
        .createShader(Offset.zero & size);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
