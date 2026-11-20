import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'puzzle_logic.dart';

const _ink = Color(0xFF1D3028);
const _forest = Color(0xFF24483C);
const _paper = Color(0xFFF6F3EC);
const _surface = Color(0xFFFFFEFB);
const _muted = Color(0xFF788078);
const _line = Color(0xFFE7E3D9);
const _lime = Color(0xFFD9ED9A);
const _coral = Color(0xFFE58B69);

void main() => runApp(const JigsawPuzzleApp());

class JigsawPuzzleApp extends StatelessWidget {
  const JigsawPuzzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(
      seedColor: _forest,
      brightness: Brightness.light,
    ).copyWith(
      primary: _forest,
      secondary: _coral,
      surface: _surface,
      onSurface: _ink,
    );

    return MaterialApp(
      title: 'Jigsaw Puzzle',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: _paper,
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            color: _ink,
            fontSize: 38,
            height: 1.08,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.7,
          ),
          headlineMedium: TextStyle(
            color: _ink,
            fontSize: 29,
            height: 1.12,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
          ),
          titleLarge: TextStyle(
            color: _ink,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          titleMedium: TextStyle(
            color: _ink,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(color: _ink, fontSize: 15, height: 1.55),
          bodyMedium: TextStyle(color: _muted, fontSize: 13, height: 1.5),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _ink,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      home: const PuzzleScreen(),
    );
  }
}

class PuzzlePiece {
  PuzzlePiece({required this.index, required this.imageBytes});

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
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 94,
      );
      if (picked == null || !mounted) return;

      setState(() => _isLoading = true);
      final bytes = await picked.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw const FormatException('This image could not be decoded.');
      }

      final pieces = _splitImage(decoded);
      if (!mounted) return;
      setState(() {
        _sourceBytes = bytes;
        _sourceAspectRatio = decoded.width / decoded.height;
        _pieces = pieces;
        _board = List<PuzzlePiece?>.filled(_columns * _rows, null);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Could not open that image. Please try another photo.');
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
        pieces.add(
          PuzzlePiece(
            index: row * _columns + column,
            imageBytes: Uint8List.fromList(img.encodePng(crop)),
          ),
        );
      }
    }

    pieces.shuffle(_random);
    return pieces;
  }

  void _changeDifficulty(int pieceCount) {
    final dimensions = PuzzleDimensions.fromPieceCount(pieceCount);
    setState(() {
      _columns = dimensions.columns;
      _rows = dimensions.rows;
    });
    if (_sourceBytes != null) _restartWithSource();
  }

  Future<void> _restartWithSource() async {
    final source = _sourceBytes;
    if (source == null) return;

    setState(() => _isLoading = true);
    try {
      final decoded = img.decodeImage(source);
      if (decoded == null) {
        throw const FormatException('The selected image is no longer available.');
      }
      final pieces = _splitImage(decoded);
      if (!mounted) return;
      setState(() {
        _pieces = pieces;
        _board = List<PuzzlePiece?>.filled(_columns * _rows, null);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('The puzzle could not be restarted. Choose the photo again.');
    }
  }

  void _placePiece(PuzzlePiece piece, int targetIndex) {
    if (piece.index != targetIndex) {
      _showMessage('Not quite. Try another spot.');
      return;
    }

    setState(() {
      _board[targetIndex] = piece;
      _pieces.removeWhere((candidate) => candidate.index == piece.index);
    });

    if (_pieces.isEmpty) _showComplete();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }

  Future<void> _showComplete() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 30, 26, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  color: _lime,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 36,
                  color: _forest,
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Beautifully done.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Every piece found its place. Take a moment to enjoy the picture you brought back together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, height: 1.55, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _restartWithSource();
                  },
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Play again'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Stay here a little longer',
                  style: TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const _LoadingScreen()
            : _sourceBytes == null
                ? _EmptyPuzzle(onPickImage: _pickImage)
                : _PuzzleView(
                    pieces: _pieces,
                    board: _board,
                    columns: _columns,
                    rows: _rows,
                    aspectRatio: _sourceAspectRatio,
                    onPickImage: _pickImage,
                    onRestart: _restartWithSource,
                    onChangeDifficulty: _changeDifficulty,
                    onPlacePiece: _placePiece,
                  ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.extension_rounded,
              color: _forest,
              size: 34,
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _forest,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Putting the pieces together…',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyPuzzle extends StatelessWidget {
  const _EmptyPuzzle({required this.onPickImage});

  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BrandHeader(),
          const SizedBox(height: 42),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _lime.withOpacity(0.48),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.spa_rounded, size: 15, color: _forest),
                SizedBox(width: 7),
                Text(
                  'A LITTLE SPACE TO UNWIND',
                  style: TextStyle(
                    color: _forest,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Make room for\nsomething beautiful.',
            style: TextStyle(
              color: _ink,
              fontSize: 39,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.8,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your favourite moments, one piece at a time. Turn any photo into a puzzle made just for you.',
            style: TextStyle(color: _muted, fontSize: 15, height: 1.6),
          ),
          const SizedBox(height: 28),
          const _PuzzleMosaic(),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 21),
              label: const Text('Choose a photo'),
            ),
          ),
          const SizedBox(height: 13),
          const Center(
            child: Text(
              'Made from your photos. Played at your pace.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Row(
            children: [
              Expanded(
                child: _FeatureNote(
                  icon: Icons.photo_library_outlined,
                  title: 'Your photos',
                  subtitle: 'Make it personal',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _FeatureNote(
                  icon: Icons.tune_rounded,
                  title: 'Your pace',
                  subtitle: 'Three challenges',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: _forest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.extension_rounded, color: _lime, size: 24),
        ),
        const SizedBox(width: 11),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JIGSAW',
              style: TextStyle(
                color: _ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.2,
              ),
            ),
            SizedBox(height: 1),
            Text(
              'A MOMENT TO YOURSELF',
              style: TextStyle(
                color: _muted,
                fontSize: 8,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _line),
          ),
          child: const Row(
            children: [
              Icon(Icons.wb_sunny_outlined, size: 14, color: _forest),
              SizedBox(width: 6),
              Text(
                'SLOW DOWN',
                style: TextStyle(
                  color: _forest,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PuzzleMosaic extends StatelessWidget {
  const _PuzzleMosaic();

  static const _tiles = [
    Color(0xFFE7A17E),
    Color(0xFFB9C7A4),
    Color(0xFFE7D6B9),
    Color(0xFF6F8C79),
    Color(0xFFE8C4A6),
    Color(0xFFC6D2B8),
    Color(0xFFD97F61),
    Color(0xFFE4D4A7),
    Color(0xFF8DA18B),
  ];

  static const _icons = [
    Icons.landscape_rounded,
    Icons.wb_sunny_rounded,
    Icons.local_florist_rounded,
    Icons.park_rounded,
    Icons.favorite_rounded,
    Icons.cloud_rounded,
    Icons.spa_rounded,
    Icons.water_rounded,
    Icons.eco_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _forest,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _forest.withOpacity(0.13),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'A CANVAS OF MEMORIES',
                    style: TextStyle(
                      color: Color(0xFFDCE8D7),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.more_horiz_rounded,
                      color: Color(0xFFDCE8D7), size: 20),
                ],
              ),
              const SizedBox(height: 13),
              GridView.builder(
                itemCount: _tiles.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 7,
                  childAspectRatio: 1.32,
                ),
                itemBuilder: (context, index) {
                  return Container(
                    decoration: BoxDecoration(
                      color: _tiles[index],
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      _icons[index],
                      color: _ink.withOpacity(0.72),
                      size: 23,
                    ),
                  );
                },
              ),
            ],
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.14),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 13, color: _forest),
                    SizedBox(width: 5),
                    Text(
                      'YOUR NEXT FAVOURITE',
                      style: TextStyle(
                        color: _forest,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureNote extends StatelessWidget {
  const _FeatureNote({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _line),
      ),
      child: Row(
        children: [
          Icon(icon, color: _forest, size: 21),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
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
    required this.onRestart,
    required this.onChangeDifficulty,
    required this.onPlacePiece,
  });

  final List<PuzzlePiece> pieces;
  final List<PuzzlePiece?> board;
  final int columns;
  final int rows;
  final double aspectRatio;
  final VoidCallback onPickImage;
  final VoidCallback onRestart;
  final ValueChanged<int> onChangeDifficulty;
  final void Function(PuzzlePiece piece, int targetIndex) onPlacePiece;

  @override
  Widget build(BuildContext context) {
    final total = columns * rows;
    final solved = total - pieces.length;
    final progress = solved / total;
    final boardWidth = min(
      MediaQuery.sizeOf(context).width - 76,
      520.0,
    ).toDouble();
    final boardHeight = boardWidth / aspectRatio;
    final cellAspectRatio = aspectRatio * rows / columns;
    final trayColumns = min(5, columns + 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: _forest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: _lime,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JIGSAW',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    Text(
                      'YOUR LITTLE MOMENT',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Restart puzzle',
                onPressed: onRestart,
              ),
              const SizedBox(width: 8),
              _RoundAction(
                icon: Icons.photo_library_outlined,
                tooltip: 'Choose another photo',
                onPressed: onPickImage,
              ),
            ],
          ),
          const SizedBox(height: 27),
          const Text(
            'PUZZLE IN PROGRESS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.45,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Stay in the flow.',
            style: TextStyle(
              color: _ink,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 17),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'PIECES PLACED',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$solved / $total',
                      style: const TextStyle(
                        color: _forest,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 11),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: _paper,
                        color: _forest,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Choose your challenge',
                style: TextStyle(
                  color: _ink,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                '$columns × $rows',
                style: const TextStyle(
                  color: _muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DifficultyChip(
                label: 'Easy',
                detail: '9 pieces',
                value: 9,
                selected: total == 9,
                onSelected: onChangeDifficulty,
              ),
              _DifficultyChip(
                label: 'Medium',
                detail: '16 pieces',
                value: 16,
                selected: total == 16,
                onSelected: onChangeDifficulty,
              ),
              _DifficultyChip(
                label: 'Hard',
                detail: '25 pieces',
                value: 25,
                selected: total == 25,
                onSelected: onChangeDifficulty,
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 15, 12, 12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _line),
              boxShadow: [
                BoxShadow(
                  color: _ink.withOpacity(0.035),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'THE BOARD',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.touch_app_outlined,
                      color: _muted,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Drag pieces into place',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Center(
                  child: Container(
                    width: boardWidth,
                    height: boardHeight,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _ink,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: GridView.builder(
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          childAspectRatio: cellAspectRatio,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: board.length,
                        itemBuilder: (context, index) {
                          final placedPiece = board[index];
                          return DragTarget<PuzzlePiece>(
                            onWillAcceptWithDetails: (_) =>
                                placedPiece == null,
                            onAcceptWithDetails: (details) =>
                                onPlacePiece(details.data, index),
                            builder: (context, candidates, rejected) {
                              final isTargeted = candidates.isNotEmpty;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 130),
                                decoration: BoxDecoration(
                                  color: isTargeted
                                      ? _lime
                                      : const Color(0xFF344B40),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isTargeted
                                        ? _lime
                                        : Colors.white.withOpacity(0.10),
                                    width: isTargeted ? 2 : 0.7,
                                  ),
                                ),
                                child: placedPiece == null
                                    ? Center(
                                        child: Icon(
                                          Icons.add_rounded,
                                          size: 17,
                                          color: Colors.white.withOpacity(0.2),
                                        ),
                                      )
                                    : ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: Image.memory(
                                          placedPiece.imageBytes,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Text(
                'Your pieces',
                style: TextStyle(
                  color: _ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _lime.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  pieces.length.toString() + ' LEFT',
                  style: const TextStyle(
                    color: _forest,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _line),
            ),
            child: pieces.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: Text(
                      'Every piece is in place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _forest,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 9,
                    runSpacing: 11,
                    children: pieces.map((piece) {
                      return _DraggablePiece(
                        piece: piece,
                        width: min(
                          (boardWidth - 18 - (trayColumns - 1) * 9) /
                              trayColumns,
                          78.0,
                        ).toDouble(),
                        aspectRatio: cellAspectRatio,
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 18),
          Center(
            child: TextButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.replay_rounded, size: 17),
              label: const Text('Start this puzzle over'),
              style: TextButton.styleFrom(
                foregroundColor: _muted,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({
    required this.piece,
    required this.width,
    required this.aspectRatio,
  });

  final PuzzlePiece piece;
  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final height = (width / aspectRatio).clamp(34.0, 110.0).toDouble();

    return Draggable<PuzzlePiece>(
      data: piece,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _lime, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Image.memory(piece.imageBytes, fit: BoxFit.fill),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.2,
        child: _PieceImage(
          bytes: piece.imageBytes,
          width: width,
          height: height,
        ),
      ),
      child: _PieceImage(
        bytes: piece.imageBytes,
        width: width,
        height: height,
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  const _PieceImage({
    required this.bytes,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: _ink.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          bytes,
          fit: BoxFit.fill,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}

class _DifficultyChip extends StatelessWidget {
  const _DifficultyChip({
    required this.label,
    required this.detail,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final String detail;
  final int value;
  final bool selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: selected ? null : () => onSelected(value),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _lime : _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _forest.withOpacity(0.18) : _line,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
          side: const BorderSide(color: _line),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 39,
            height: 39,
            child: Icon(icon, color: _forest, size: 20),
          ),
        ),
      ),
    );
  }
}
