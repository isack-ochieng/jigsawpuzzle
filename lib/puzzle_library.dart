import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

class PuzzleArtwork {
  const PuzzleArtwork({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.skyTop,
    required this.skyBottom,
    required this.land,
    required this.accent,
    required this.style,
  });

  final String id;
  final String title;
  final String subtitle;
  final Color skyTop;
  final Color skyBottom;
  final Color land;
  final Color accent;
  final int style;
}

const puzzleArtworks = <PuzzleArtwork>[
  PuzzleArtwork(
    id: 'golden-hour',
    title: 'Golden hour',
    subtitle: 'A quiet evening by the water',
    skyTop: Color(0xFFDA9879),
    skyBottom: Color(0xFFF0D2A6),
    land: Color(0xFF456E69),
    accent: Color(0xFFF4D47D),
    style: 0,
  ),
  PuzzleArtwork(
    id: 'quiet-garden',
    title: 'Quiet garden',
    subtitle: 'A little colour in the calm',
    skyTop: Color(0xFFB8C8B2),
    skyBottom: Color(0xFFE9D9BC),
    land: Color(0xFF66816B),
    accent: Color(0xFFD88370),
    style: 1,
  ),
  PuzzleArtwork(
    id: 'highland-morning',
    title: 'Highland morning',
    subtitle: 'Fresh air and distant peaks',
    skyTop: Color(0xFF8AAEB3),
    skyBottom: Color(0xFFE4D9BB),
    land: Color(0xFF526D68),
    accent: Color(0xFFE9E1C9),
    style: 2,
  ),
  PuzzleArtwork(
    id: 'desert-bloom',
    title: 'Desert bloom',
    subtitle: 'Warm horizons, wild flowers',
    skyTop: Color(0xFFCC8F74),
    skyBottom: Color(0xFFF0C99E),
    land: Color(0xFF9A765C),
    accent: Color(0xFFD9B86F),
    style: 3,
  ),
];

Future<Uint8List> renderPuzzleArtwork(
  PuzzleArtwork artwork, {
  int width = 1400,
  int height = 1050,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  PuzzleArtworkPainter(artwork).paint(
    canvas,
    Size(width.toDouble(), height.toDouble()),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) {
    throw StateError('Could not render the selected artwork.');
  }
  return data.buffer.asUint8List();
}

class PuzzleArtworkPainter extends CustomPainter {
  const PuzzleArtworkPainter(this.artwork);

  final PuzzleArtwork artwork;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final scale = size.width / 1400;
    final paint = Paint()..style = PaintingStyle.fill;

    paint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [artwork.skyTop, artwork.skyBottom],
    ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;

    final sunCenter = Offset(size.width * 0.72, size.height * 0.29);
    canvas.drawCircle(
      sunCenter,
      size.shortestSide * 0.105,
      Paint()..color = artwork.accent.withValues(alpha: 0.96),
    );
    canvas.drawCircle(
      sunCenter,
      size.shortestSide * 0.145,
      Paint()..color = artwork.accent.withValues(alpha: 0.13),
    );

    if (artwork.style == 0) {
      _paintWater(canvas, size, scale);
    } else if (artwork.style == 1) {
      _paintGarden(canvas, size, scale);
    } else if (artwork.style == 2) {
      _paintHighlands(canvas, size, scale);
    } else {
      _paintDesert(canvas, size, scale);
    }

    final grain = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1.2 * scale;
    for (var i = 0; i < 18; i++) {
      final x = (i * 83.0 % 1400) * scale;
      final y = (i * 137.0 % 1050) * scale;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 42 * scale, y),
        grain,
      );
    }
  }

  void _paintWater(Canvas canvas, Size size, double scale) {
    final horizon = size.height * 0.57;
    final water = Paint()..color = const Color(0xFF7D9B8C);
    canvas.drawRect(
      Rect.fromLTWH(0, horizon, size.width, size.height - horizon),
      water,
    );
    _drawMountain(
      canvas,
      size,
      [Offset(0, horizon), Offset(size.width * 0.27, size.height * 0.30),
       Offset(size.width * 0.50, horizon)],
      const Color(0xFF6A7770),
    );
    _drawMountain(
      canvas,
      size,
      [Offset(size.width * 0.28, horizon),
       Offset(size.width * 0.60, size.height * 0.36),
       Offset(size.width * 0.91, horizon)],
      const Color(0xFF526E67),
    );
    final line = Paint()
      ..color = const Color(0xFFEED7A8).withValues(alpha: 0.72)
      ..strokeWidth = 3 * scale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final y = horizon + (i + 1) * 26 * scale;
      final width = (150 + (i % 3) * 70) * scale;
      canvas.drawLine(
        Offset(size.width * 0.65 - width / 2, y),
        Offset(size.width * 0.65 + width / 2, y),
        line,
      );
    }
    _drawHill(
      canvas,
      size,
      size.height * 0.83,
      const Color(0xFF34584E),
      0.24,
    );
  }

  void _paintGarden(Canvas canvas, Size size, double scale) {
    _drawHill(canvas, size, size.height * 0.72, artwork.land, 0.20);
    _drawHill(
      canvas,
      size,
      size.height * 0.86,
      const Color(0xFF496D55),
      0.13,
    );
    final stem = Paint()
      ..color = const Color(0xFF3F654C)
      ..strokeWidth = 7 * scale
      ..strokeCap = StrokeCap.round;
    final flowers = [
      Offset(size.width * 0.18, size.height * 0.72),
      Offset(size.width * 0.34, size.height * 0.78),
      Offset(size.width * 0.54, size.height * 0.68),
      Offset(size.width * 0.82, size.height * 0.76),
    ];
    for (var i = 0; i < flowers.length; i++) {
      final point = flowers[i];
      canvas.drawLine(
        Offset(point.dx, size.height),
        point,
        stem,
      );
      canvas.drawCircle(
        point,
        15 * scale,
        Paint()..color = artwork.accent,
      );
      for (var petal = 0; petal < 5; petal++) {
        final angle = petal * 1.256;
        canvas.drawCircle(
          Offset(
            point.dx + math.cos(angle) * 22 * scale,
            point.dy + math.sin(angle) * 22 * scale,
          ),
          11 * scale,
          Paint()
            ..color = i.isEven
                ? const Color(0xFFF2D8B6)
                : const Color(0xFFE9B69A),
        );
      }
    }
  }

  void _paintHighlands(Canvas canvas, Size size, double scale) {
    _drawMountain(
      canvas,
      size,
      [Offset(0, size.height * 0.77),
       Offset(size.width * 0.28, size.height * 0.24),
       Offset(size.width * 0.55, size.height * 0.77)],
      const Color(0xFF91A39B),
    );
    _drawMountain(
      canvas,
      size,
      [Offset(size.width * 0.32, size.height * 0.77),
       Offset(size.width * 0.67, size.height * 0.15),
       Offset(size.width, size.height * 0.77)],
      artwork.land,
    );
    _drawHill(
      canvas,
      size,
      size.height * 0.86,
      const Color(0xFF435F52),
      0.15,
    );
    final snow = Paint()
      ..color = const Color(0xFFF3EBDD)
      ..style = PaintingStyle.fill;
    final cap = Path()
      ..moveTo(size.width * 0.61, size.height * 0.27)
      ..lineTo(size.width * 0.67, size.height * 0.15)
      ..lineTo(size.width * 0.74, size.height * 0.29)
      ..lineTo(size.width * 0.68, size.height * 0.25)
      ..lineTo(size.width * 0.65, size.height * 0.30)
      ..close();
    canvas.drawPath(cap, snow);
  }

  void _paintDesert(Canvas canvas, Size size, double scale) {
    _drawHill(
      canvas,
      size,
      size.height * 0.72,
      const Color(0xFFD5A16E),
      0.22,
    );
    _drawHill(
      canvas,
      size,
      size.height * 0.88,
      artwork.land,
      0.12,
    );
    final cactus = Paint()
      ..color = const Color(0xFF526F57)
      ..strokeWidth = 19 * scale
      ..strokeCap = StrokeCap.round;
    final x = size.width * 0.28;
    final base = size.height * 0.91;
    canvas.drawLine(Offset(x, base), Offset(x, size.height * 0.59), cactus);
    canvas.drawLine(
      Offset(x, size.height * 0.73),
      Offset(x - 45 * scale, size.height * 0.73),
      cactus,
    );
    canvas.drawLine(
      Offset(x - 45 * scale, size.height * 0.73),
      Offset(x - 45 * scale, size.height * 0.65),
      cactus,
    );
    canvas.drawLine(
      Offset(x, size.height * 0.79),
      Offset(x + 48 * scale, size.height * 0.79),
      cactus,
    );
    canvas.drawLine(
      Offset(x + 48 * scale, size.height * 0.79),
      Offset(x + 48 * scale, size.height * 0.70),
      cactus,
    );
  }

  void _drawHill(
    Canvas canvas,
    Size size,
    double top,
    Color color,
    double wave,
  ) {
    final path = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(
        size.width * 0.5,
        top - size.height * wave,
        size.width,
        top,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _drawMountain(
    Canvas canvas,
    Size size,
    List<Offset> points,
    Color color,
  ) {
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..lineTo(points[2].dx, size.height)
      ..lineTo(points[0].dx, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant PuzzleArtworkPainter oldDelegate) {
    return oldDelegate.artwork.id != artwork.id;
  }
}

class PuzzleLibrarySheet extends StatelessWidget {
  const PuzzleLibrarySheet({super.key, required this.onSelected});

  final ValueChanged<PuzzleArtwork> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDAD8CF),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'The little collection',
              style: TextStyle(
                color: Color(0xFF1D3028),
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'A few quiet scenes, ready to be pieced together.',
              style: TextStyle(
                color: Color(0xFF788078),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 18),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                itemCount: puzzleArtworks.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 13,
                  crossAxisSpacing: 13,
                  childAspectRatio: 0.92,
                ),
                itemBuilder: (context, index) {
                  final artwork = puzzleArtworks[index];
                  return InkWell(
                    onTap: () => onSelected(artwork),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFEFB),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE7E3D9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CustomPaint(
                                painter: PuzzleArtworkPainter(artwork),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            artwork.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1D3028),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artwork.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF788078),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
