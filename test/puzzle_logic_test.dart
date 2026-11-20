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

  group('PuzzleShapes', () {
    test('neighbouring horizontal edges are complementary', () {
      const columns = 5;
      const rows = 4;
      final shapes = generatePuzzleShapes(columns, rows, seed: 8675309);

      for (var row = 0; row < rows; row++) {
        for (var column = 0; column < columns - 1; column++) {
          final left = shapes[row * columns + column];
          final right = shapes[row * columns + column + 1];
          expect(left.right, -right.left);
        }
      }
    });

    test('neighbouring vertical edges are complementary', () {
      const columns = 4;
      const rows = 5;
      final shapes = generatePuzzleShapes(columns, rows, seed: 42);

      for (var row = 0; row < rows - 1; row++) {
        for (var column = 0; column < columns; column++) {
          final upper = shapes[row * columns + column];
          final lower = shapes[(row + 1) * columns + column];
          expect(upper.bottom, -lower.top);
        }
      }
    });

    test('outside edges stay flat and layouts are deterministic', () {
      const columns = 3;
      const rows = 3;
      final first = generatePuzzleShapes(columns, rows, seed: 99);
      final second = generatePuzzleShapes(columns, rows, seed: 99);

      expect(first, second);
      for (var row = 0; row < rows; row++) {
        expect(first[row * columns].left, 0);
        expect(first[row * columns + columns - 1].right, 0);
      }
      for (var column = 0; column < columns; column++) {
        expect(first[column].top, 0);
        expect(first[(rows - 1) * columns + column].bottom, 0);
      }
    });

    test('rejects non-positive grid dimensions', () {
      expect(() => generatePuzzleShapes(0, 3), throwsArgumentError);
      expect(() => generatePuzzleShapes(3, 0), throwsArgumentError);
    });
  });

  test('shuffled indexes preserve every puzzle position', () {
    final indexes = shuffledPieceIndexes(25, Random(42));

    expect(indexes.length, 25);
    expect(indexes.toSet(), Set<int>.from(List.generate(25, (index) => index)));
  });
}
