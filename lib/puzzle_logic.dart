import 'dart:math';

class PuzzleDimensions {
  const PuzzleDimensions({required this.columns, required this.rows});

  final int columns;
  final int rows;
  int get pieceCount => columns * rows;

  @override
  bool operator ==(Object other) {
    return other is PuzzleDimensions &&
        columns == other.columns &&
        rows == other.rows;
  }

  @override
  int get hashCode => Object.hash(columns, rows);

  static PuzzleDimensions fromPieceCount(int pieces) {
    if (pieces <= 0) {
      throw ArgumentError.value(pieces, 'pieces', 'Must be positive');
    }

    final side = sqrt(pieces).round();
    final columns = side;
    final rows = (pieces / columns).ceil();
    if (columns * rows < pieces) {
      throw StateError('Invalid puzzle dimensions');
    }
    return PuzzleDimensions(columns: columns, rows: rows);
  }
}

/// Describes the four edges of one piece.
/// 1 is a tab, -1 is a socket, and 0 is a flat outside edge.
class PuzzleShape {
  const PuzzleShape({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  final int top;
  final int right;
  final int bottom;
  final int left;

  List<int> get edges => [top, right, bottom, left];

  @override
  bool operator ==(Object other) {
    return other is PuzzleShape &&
        top == other.top &&
        right == other.right &&
        bottom == other.bottom &&
        left == other.left;
  }

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Generates complementary edge pairs from a stable seed.
/// Every internal edge is a tab on one piece and a socket on its neighbour.
List<PuzzleShape> generatePuzzleShapes(
  int columns,
  int rows, {
  int seed = 42,
}) {
  if (columns <= 0 || rows <= 0) {
    throw ArgumentError('Puzzle dimensions must be positive.');
  }

  final random = Random(seed);
  final vertical = List.generate(
    rows,
    (_) => List.generate(
      columns + 1,
      (boundary) => boundary == 0 || boundary == columns
          ? 0
          : (random.nextBool() ? 1 : -1),
    ),
  );
  final horizontal = List.generate(
    rows + 1,
    (rowBoundary) => List.generate(
      columns,
      (_) => rowBoundary == 0 || rowBoundary == rows
          ? 0
          : (random.nextBool() ? 1 : -1),
    ),
  );

  return List<PuzzleShape>.generate(columns * rows, (index) {
    final row = index ~/ columns;
    final column = index % columns;

    return PuzzleShape(
      top: -horizontal[row][column],
      right: vertical[row][column + 1],
      bottom: horizontal[row + 1][column],
      left: -vertical[row][column],
    );
  });
}

List<int> shuffledPieceIndexes(int pieceCount, [Random? random]) {
  if (pieceCount < 0) {
    throw ArgumentError.value(pieceCount, 'pieceCount', 'Cannot be negative');
  }
  final indexes = List<int>.generate(pieceCount, (index) => index);
  indexes.shuffle(random);
  return indexes;
}
