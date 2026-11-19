import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jigsaw_puzzle/puzzle_logic.dart';

void main() {
  group('PuzzleDimensions', () {
    test('creates a 3 by 3 grid for 9 pieces', () {
      expect(PuzzleDimensions.fromPieceCount(9),
          const PuzzleDimensions(columns: 3, rows: 3));
    });

    test('creates a 4 by 4 grid for 16 pieces', () {
      expect(PuzzleDimensions.fromPieceCount(16),
          const PuzzleDimensions(columns: 4, rows: 4));
    });

    test('creates a 5 by 5 grid for 25 pieces', () {
      expect(PuzzleDimensions.fromPieceCount(25),
          const PuzzleDimensions(columns: 5, rows: 5));
    });

    test('rejects zero pieces', () {
      expect(
        () => PuzzleDimensions.fromPieceCount(0),
        throwsArgumentError,
      );
    });
  });

  test('shuffled indexes preserve every puzzle position', () {
    final indexes = shuffledPieceIndexes(25, Random(42));

    expect(indexes.length, 25);
    expect(indexes.toSet(), Set<int>.from(List.generate(25, (index) => index)));
  });
}
