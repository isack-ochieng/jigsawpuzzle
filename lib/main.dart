import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'puzzle_logic.dart';

void main() {
  runApp(const JigsawPuzzleApp());
}

class JigsawPuzzleApp extends StatelessWidget {
  const JigsawPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jigsaw Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PuzzleScreen(),
    );
  }
}

class PuzzlePiece {
  PuzzlePiece({
    required this.index,
    required this.imageBytes,
  });

  final int index;
  final Uint8List imageBytes;
}

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen> {
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();

  Uint8List? _sourceBytes;
  double _sourceAspectRatio = 1;
  List<PuzzlePiece> _pieces = [];
  List<PuzzlePiece?> _board = [];
  int _columns = 3;
  int _rows = 3;
  bool _isLoading = false;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 92,
    );
    if (picked == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await picked.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) throw const FormatException('Unsupported image');

      final pieces = _splitImage(decoded);
      if (!mounted) return;
      setState(() {
        _sourceBytes = bytes;
        _sourceAspectRatio = decoded.width / decoded.height;
        _pieces = pieces;
        _board = List<PuzzlePiece?>.filled(_columns * _rows, null);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this image: $error')),
      );
    }
  }

  List<PuzzlePiece> _splitImage(img.Image source) {
    final pieces = <PuzzlePiece>[];

    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        final left = (column * source.width / _columns).floor();
        final top = (row * source.height / _rows).floor();
        final right = ((column + 1) * source.width / _columns).ceil();
        final bottom = ((row + 1) * source.height / _rows).ceil();
        final crop = img.copyCrop(
          source,
          x: left,
          y: top,
          width: max(1, right - left),
          height: max(1, bottom - top),
        );
        pieces.add(PuzzlePiece(
          index: row * _columns + column,
          imageBytes: Uint8List.fromList(img.encodePng(crop)),
        ));
      }
    }
    pieces.shuffle(_random);
    return pieces;
  }

  void _changeDifficulty(int pieces) {
    final dimensions = PuzzleDimensions.fromPieceCount(pieces);
    setState(() {
      _columns = dimensions.columns;
      _rows = dimensions.rows;
    });
    if (_sourceBytes != null) {
      _restartWithSource();
    }
  }

  Future<void> _restartWithSource() async {
    if (_sourceBytes == null) return;
    setState(() => _isLoading = true);
    final decoded = img.decodeImage(_sourceBytes!);
    if (decoded == null) return;
    final pieces = _splitImage(decoded);
    if (!mounted) return;
    setState(() {
      _pieces = pieces;
      _board = List<PuzzlePiece?>.filled(_columns * _rows, null);
      _isLoading = false;
    });
  }

  void _placePiece(PuzzlePiece piece, int targetIndex) {
    if (piece.index != targetIndex) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That piece belongs somewhere else'),
          duration: Duration(milliseconds: 700),
        ),
      );
      return;
    }
    setState(() {
      _board[targetIndex] = piece;
      _pieces.removeWhere((candidate) => candidate.index == piece.index);
    });
    if (_pieces.isEmpty) _showComplete();
  }

  Future<void> _showComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Puzzle complete!'),
        content: const Text('Excellent work. You restored the picture.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _restartWithSource();
            },
            child: const Text('Play again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jigsaw Puzzle'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Number of pieces',
            onSelected: _changeDifficulty,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 9, child: Text('Easy · 9 pieces')),
              PopupMenuItem(value: 16, child: Text('Medium · 16 pieces')),
              PopupMenuItem(value: 25, child: Text('Hard · 25 pieces')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sourceBytes == null
                ? _EmptyPuzzle(onPickImage: _pickImage)
                : _PuzzleView(
                    pieces: _pieces,
                    board: _board,
                    columns: _columns,
                    rows: _rows,
                    aspectRatio: _sourceAspectRatio,
                    onPickImage: _pickImage,
                    onPlacePiece: _placePiece,
                  ),
      ),
    );
  }
}

class _EmptyPuzzle extends StatelessWidget {
  const _EmptyPuzzle({required this.onPickImage});

  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.extension_rounded, size: 72),
            const SizedBox(height: 16),
            Text(
              'Create your puzzle',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a photo, and we will split it into pieces.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose image'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PuzzleView extends StatelessWidget {
  const _PuzzleView({
    required this.pieces,
    required this.board,
    required this.columns,
    required this.rows,
    required this.aspectRatio,
    required this.onPickImage,
    required this.onPlacePiece,
  });

  final List<PuzzlePiece> pieces;
  final List<PuzzlePiece?> board;
  final int columns;
  final int rows;
  final double aspectRatio;
  final VoidCallback onPickImage;
  final void Function(PuzzlePiece piece, int targetIndex) onPlacePiece;

  @override
  Widget build(BuildContext context) {
    final boardWidth = min(
      MediaQuery.sizeOf(context).width - 32,
      600.0,
    );
    final boardHeight = boardWidth / aspectRatio;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '${pieces.length} pieces remaining',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: onPickImage,
                icon: const Icon(Icons.image),
                label: const Text('New image'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: SizedBox(
              width: boardWidth,
              height: boardHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: (boardWidth / columns) /
                      (boardHeight / rows),
                ),
                itemCount: board.length,
                itemBuilder: (context, index) {
                  final placedPiece = board[index];
                  return DragTarget<PuzzlePiece>(
                    onWillAcceptWithDetails: (_) => placedPiece == null,
                    onAcceptWithDetails: (details) =>
                        onPlacePiece(details.data, index),
                    builder: (context, candidates, rejected) {
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: candidates.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : Colors.black26,
                          ),
                          color: candidates.isNotEmpty
                              ? Theme.of(context)
                                  .colorScheme
                                  .primaryContainer
                                  .withOpacity(0.4)
                              : null,
                        ),
                        child: placedPiece == null
                            ? null
                            : Image.memory(
                                placedPiece.imageBytes,
                                fit: BoxFit.fill,
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pieces',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: pieces.map((piece) {
              return Draggable<PuzzlePiece>(
                data: piece,
                feedback: Material(
                  elevation: 4,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.memory(piece.imageBytes, fit: BoxFit.cover),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.25,
                  child: Image.memory(
                    piece.imageBytes,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                child: Image.memory(
                  piece.imageBytes,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
