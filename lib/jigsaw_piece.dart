import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'puzzle_logic.dart';

Path buildJigsawPiecePath(Rect coreRect, PuzzleShape shape) {
  final depth = coreRect.shortestSide * 0.22;
  final path = Path()..moveTo(coreRect.left, coreRect.top);

  _addPuzzleEdge(
    path,
    Offset(coreRect.left, coreRect.top),
    Offset(coreRect.right, coreRect.top),
    const Offset(0, -1),
    shape.top,
    depth,
  );
  _addPuzzleEdge(
    path,
    Offset(coreRect.right, coreRect.top),
    Offset(coreRect.right, coreRect.bottom),
    const Offset(1, 0),
    shape.right,
    depth,
  );
  _addPuzzleEdge(
    path,
    Offset(coreRect.right, coreRect.bottom),
    Offset(coreRect.left, coreRect.bottom),
    const Offset(0, 1),
    shape.bottom,
    depth,
  );
  _addPuzzleEdge(
    path,
    Offset(coreRect.left, coreRect.bottom),
    Offset(coreRect.left, coreRect.top),
    const Offset(-1, 0),
    shape.left,
    depth,
  );

  return path..close();
}

void _addPuzzleEdge(
  Path path,
  Offset start,
  Offset end,
  Offset outward,
  int edge,
  double depth,
) {
  final delta = end - start;
  Offset point(double t) => start + delta * t;

  if (edge == 0) {
    path.lineTo(end.dx, end.dy);
    return;
  }

  final direction = edge.toDouble();
  final p1 = point(0.32);
  final p2 = point(0.41);
  final p3 = point(0.59);
  final p4 = point(0.68);
  final normal = outward * direction;

  path.lineTo(p1.dx, p1.dy);
  path.cubicTo(
    p1.dx + normal.dx * depth * 0.12,
    p1.dy + normal.dy * depth * 0.12,
    p2.dx + normal.dx * depth * 0.95,
    p2.dy + normal.dy * depth * 0.95,
    p2.dx,
    p2.dy,
  );
  path.cubicTo(
    p2.dx + normal.dx * depth * 1.45,
    p2.dy + normal.dy * depth * 1.45,
    p3.dx + normal.dx * depth * 1.45,
    p3.dy + normal.dy * depth * 1.45,
    p3.dx,
    p3.dy,
  );
  path.cubicTo(
    p3.dx + normal.dx * depth * 0.95,
    p3.dy + normal.dy * depth * 0.95,
    p4.dx + normal.dx * depth * 0.12,
    p4.dy + normal.dy * depth * 0.12,
    p4.dx,
    p4.dy,
  );
  path.lineTo(end.dx, end.dy);
}

class JigsawPieceClipper extends CustomClipper<Path> {
  const JigsawPieceClipper({
    required this.shape,
    required this.coreRect,
  });

  final PuzzleShape shape;

  /// The piece's rectangular image area, normalized to 0..1.
  final Rect coreRect;

  @override
  Path getClip(Size size) {
    final rect = Rect.fromLTRB(
      coreRect.left * size.width,
      coreRect.top * size.height,
      coreRect.right * size.width,
      coreRect.bottom * size.height,
    );
    return buildJigsawPiecePath(rect, shape);
  }

  @override
  bool shouldReclip(covariant JigsawPieceClipper oldClipper) {
    return oldClipper.shape != shape || oldClipper.coreRect != coreRect;
  }
}

class JigsawPieceImage extends StatelessWidget {
  const JigsawPieceImage({
    super.key,
    required this.bytes,
    required this.shape,
    required this.coreRect,
    this.fit = BoxFit.fill,
  });

  final Uint8List bytes;
  final PuzzleShape shape;
  final Rect coreRect;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: JigsawPieceClipper(shape: shape, coreRect: coreRect),
      child: Image.memory(
        bytes,
        fit: fit,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class PuzzleBoardPainter extends CustomPainter {
  const PuzzleBoardPainter({
    required this.columns,
    required this.rows,
    required this.shapes,
    required this.marginX,
    required this.marginY,
    required this.backgroundColor,
    required this.lineColor,
  });

  final int columns;
  final int rows;
  final List<PuzzleShape> shapes;
  final double marginX;
  final double marginY;
  final Color backgroundColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cellWidth = (size.width - marginX * 2) / columns;
    final cellHeight = (size.height - marginY * 2) / rows;
    final fill = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    final paths = <Path>[];
    for (var index = 0; index < shapes.length; index++) {
      final row = index ~/ columns;
      final column = index % columns;
      final core = Rect.fromLTWH(
        marginX + column * cellWidth,
        marginY + row * cellHeight,
        cellWidth,
        cellHeight,
      );
      paths.add(buildJigsawPiecePath(core, shapes[index]));
    }

    for (final path in paths) {
      canvas.drawPath(path, fill);
    }
    for (final path in paths) {
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant PuzzleBoardPainter oldDelegate) {
    return oldDelegate.columns != columns ||
        oldDelegate.rows != rows ||
        oldDelegate.shapes != shapes ||
        oldDelegate.marginX != marginX ||
        oldDelegate.marginY != marginY ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.lineColor != lineColor;
  }
}
