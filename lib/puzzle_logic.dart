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

List<int> shuffledPieceIndexes(int pieceCount, [Random? random]) {
  if (pieceCount < 0) {
    throw ArgumentError.value(pieceCount, 'pieceCount', 'Cannot be negative');
  }
  final indexes = List<int>.generate(pieceCount, (index) => index);
  indexes.shuffle(random);
  return indexes;
}
