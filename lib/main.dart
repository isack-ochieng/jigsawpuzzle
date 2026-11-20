import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'jigsaw_piece.dart';
import 'puzzle_library.dart';
import 'puzzle_logic.dart';

const _ink = Color(0xFF1D3028);
const _forest = Color(0xFF24483C);
const _paper = Color(0xFFF6F3EC);
const _surface = Color(0xFFFFFEFB);
const _muted = Color(0xFF788078);
const _line = Color(0xFFE7E3D9);
const _lime = Color(0xFFD9ED9A);
const _saveKey = 'jigsaw.activePuzzle.v1';

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
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: _forest,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
  const PuzzlePiece({
    required this.index,
    required this.imageBytes,
    required this.shape,
    required this.coreRect,
  });

  final int index;
  final Uint8List imageBytes;
  final PuzzleShape shape;
  final Rect coreRect;
}

class _SavedPuzzle {
  const _SavedPuzzle({
    required this.imagePath,
    required this.title,
    required this.columns,
    required this.rows,
    required this.seed,
    required this.moves,
    required this.elapsedSeconds,
    required this.placedIndexes,
  });

  final String imagePath;
  final String title;
  final int columns;
  final int rows;
  final int seed;
  final int moves;
  final int elapsedSeconds;
  final List<int> placedIndexes;
}

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final Random _random = Random();
  final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Uint8List? _sourceBytes;
  String? _activeImagePath;
  String _puzzleTitle = 'My photo';
  double _sourceAspectRatio = 1;
  List<PuzzlePiece> _pieces = [];
  List<PuzzlePiece?> _board = [];
  int _columns = 3;
  int _rows = 3;
  int _shapeSeed = 42;
  int _moves = 0;
  int _elapsedSeconds = 0;
  bool _isLoading = false;
  bool _hasStarted = false;
  Timer? _clock;
  _SavedPuzzle? _savedPuzzle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restoreSavedPuzzle();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _clock?.cancel();
      unawaited(_persistActivePuzzle());
    } else if (state == AppLifecycleState.resumed &&
        _hasStarted &&
        _pieces.isNotEmpty) {
      _startClock();
    }
  }

  Future<void> _restoreSavedPuzzle() async {
    try {
      final raw = await _preferences.getString(_saveKey);
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final path = data['imagePath'] as String?;
      if (path == null || !await File(path).exists()) {
        await _preferences.remove(_saveKey);
        return;
      }

      final placed = (data['placedIndexes'] as List<dynamic>? ?? [])
          .map((value) => (value as num).toInt())
          .toList();

      if (!mounted) return;
      setState(() {
        _savedPuzzle = _SavedPuzzle(
          imagePath: path,
          title: data['title'] as String? ?? 'Saved puzzle',
          columns: (data['columns'] as num?)?.toInt() ?? 3,
          rows: (data['rows'] as num?)?.toInt() ?? 3,
          seed: (data['seed'] as num?)?.toInt() ?? 42,
          moves: (data['moves'] as num?)?.toInt() ?? 0,
          elapsedSeconds: (data['elapsedSeconds'] as num?)?.toInt() ?? 0,
          placedIndexes: placed,
        );
      });
    } catch (_) {
      await _preferences.remove(_saveKey);
    }
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;
      setState(() => _isLoading = true);

      final bytes = await picked.readAsBytes();
      final directory = await getApplicationDocumentsDirectory();
      final file = File(directory.path + '/jigsaw_active_image.dat');
      await file.writeAsBytes(bytes, flush: true);

      await _loadPuzzle(
        bytes: bytes,
        imagePath: file.path,
        title: 'Your photo',
        columns: _columns,
        rows: _rows,
        seed: DateTime.now().microsecondsSinceEpoch,
        moves: 0,
        elapsedSeconds: 0,
        placedIndexes: const [],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Could not open that photo. Please try another one.');
    }
  }

  Future<void> _openLibrary() async {
    final artwork = await showModalBottomSheet<PuzzleArtwork>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return PuzzleLibrarySheet(
          onSelected: (selection) {
            Navigator.of(sheetContext).pop(selection);
          },
        );
      },
    );

    if (artwork == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      final bytes = await renderPuzzleArtwork(artwork);
      final directory = await getApplicationDocumentsDirectory();
      final file = File(directory.path + '/jigsaw_active_image.dat');
      await file.writeAsBytes(bytes, flush: true);
      await _loadPuzzle(
        bytes: bytes,
        imagePath: file.path,
        title: artwork.title,
        columns: _columns,
        rows: _rows,
        seed: DateTime.now().microsecondsSinceEpoch,
        moves: 0,
        elapsedSeconds: 0,
        placedIndexes: const [],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('That puzzle could not be opened. Please try again.');
    }
  }

  Future<void> _resumeSavedPuzzle() async {
    final saved = _savedPuzzle;
    if (saved == null) return;
    setState(() => _isLoading = true);

    try {
      final file = File(saved.imagePath);
      if (!await file.exists()) {
        await _preferences.remove(_saveKey);
        if (!mounted) return;
        setState(() {
          _savedPuzzle = null;
          _isLoading = false;
        });
        _showMessage('The saved photo is no longer available.');
        return;
      }

      await _loadPuzzle(
        bytes: await file.readAsBytes(),
        imagePath: saved.imagePath,
        title: saved.title,
        columns: saved.columns,
        rows: saved.rows,
        seed: saved.seed,
        moves: saved.moves,
        elapsedSeconds: saved.elapsedSeconds,
        placedIndexes: saved.placedIndexes,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Could not restore that puzzle.');
    }
  }

  Future<void> _loadPuzzle({
    required Uint8List bytes,
    required String imagePath,
    required String title,
    required int columns,
    required int rows,
    required int seed,
    required int moves,
    required int elapsedSeconds,
    required List<int> placedIndexes,
  }) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('The selected image is not supported.');
    }

    final pieces = _splitImage(decoded, columns, rows, seed);
    final placedSet = placedIndexes.toSet();
    final nextBoard = List<PuzzlePiece?>.filled(columns * rows, null);
    final remaining = <PuzzlePiece>[];

    for (final piece in pieces) {
      if (placedSet.contains(piece.index)) {
        nextBoard[piece.index] = piece;
      } else {
        remaining.add(piece);
      }
    }
    remaining.shuffle(_random);

    if (!mounted) return;
    _clock?.cancel();
    setState(() {
      _sourceBytes = bytes;
      _activeImagePath = imagePath;
      _puzzleTitle = title;
      _columns = columns;
      _rows = rows;
      _shapeSeed = seed;
      _sourceAspectRatio = decoded.width / decoded.height;
      _pieces = remaining;
      _board = nextBoard;
      _moves = moves;
      _elapsedSeconds = elapsedSeconds;
      _hasStarted = moves > 0 || elapsedSeconds > 0;
      _isLoading = false;
      _savedPuzzle = null;
    });

    await _persistActivePuzzle();
    if (_hasStarted && _pieces.isNotEmpty) _startClock();
  }

  List<PuzzlePiece> _splitImage(
    img.Image source,
    int columns,
    int rows,
    int seed,
  ) {
    final pieces = <PuzzlePiece>[];
    final shapes = generatePuzzleShapes(columns, rows, seed: seed);

    for (var row = 0; row < rows; row++) {
      for (var column = 0; column < columns; column++) {
        final left = (column * source.width / columns).floor();
        final top = (row * source.height / rows).floor();
        final right = ((column + 1) * source.width / columns).ceil();
        final bottom = ((row + 1) * source.height / rows).ceil();
        final cellWidth = right - left;
        final cellHeight = bottom - top;
        final paddingX = max(2, (cellWidth * 0.24).round());
        final paddingY = max(2, (cellHeight * 0.24).round());

        final cropLeft = max(0, left - paddingX);
        final cropTop = max(0, top - paddingY);
        final cropRight = min(source.width, right + paddingX);
        final cropBottom = min(source.height, bottom + paddingY);
        final crop = img.copyCrop(
          source,
          x: cropLeft,
          y: cropTop,
          width: max(1, cropRight - cropLeft),
          height: max(1, cropBottom - cropTop),
        );

        final core = Rect.fromLTRB(
          (left - cropLeft) / crop.width,
          (top - cropTop) / crop.height,
          (right - cropLeft) / crop.width,
          (bottom - cropTop) / crop.height,
        );
        final index = row * columns + column;

        pieces.add(
          PuzzlePiece(
            index: index,
            imageBytes: Uint8List.fromList(img.encodePng(crop)),
            shape: shapes[index],
            coreRect: core,
          ),
        );
      }
    }

    pieces.shuffle(_random);
    return pieces;
  }

  Future<void> _changeDifficulty(int pieceCount) async {
    final dimensions = PuzzleDimensions.fromPieceCount(pieceCount);
    final source = _sourceBytes;
    final path = _activeImagePath;
    if (source == null || path == null) return;

    await _loadPuzzle(
      bytes: source,
      imagePath: path,
      title: _puzzleTitle,
      columns: dimensions.columns,
      rows: dimensions.rows,
      seed: _shapeSeed,
      moves: 0,
      elapsedSeconds: 0,
      placedIndexes: const [],
    );
  }

  Future<void> _restartPuzzle() async {
    final source = _sourceBytes;
    final path = _activeImagePath;
    if (source == null || path == null) return;

    await _loadPuzzle(
      bytes: source,
      imagePath: path,
      title: _puzzleTitle,
      columns: _columns,
      rows: _rows,
      seed: _shapeSeed,
      moves: 0,
      elapsedSeconds: 0,
      placedIndexes: const [],
    );
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _pieces.isEmpty) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds % 5 == 0) {
        unawaited(_persistActivePuzzle());
      }
    });
  }

  void _onPlacePiece(PuzzlePiece piece, int targetIndex) {
    if (_pieces.isEmpty) return;

    setState(() {
      _moves++;
      _hasStarted = true;
    });
    if (_clock == null || !_clock!.isActive) _startClock();

    if (piece.index != targetIndex) {
      _showMessage('Not quite. Look for the matching shape.');
      unawaited(_persistActivePuzzle());
      return;
    }

    setState(() {
      _board[targetIndex] = piece;
      _pieces.removeWhere((candidate) => candidate.index == piece.index);
    });

    if (_pieces.isEmpty) {
      unawaited(_finishPuzzle());
    } else {
      unawaited(_persistActivePuzzle());
    }
  }

  Future<void> _finishPuzzle() async {
    _clock?.cancel();
    await _preferences.remove(_saveKey);
    _savedPuzzle = null;

    if (!mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 26),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
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
              const SizedBox(height: 19),
              const Text(
                'Beautifully done.',
                style: TextStyle(
                  color: _ink,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You brought ' + _puzzleTitle + ' back together.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ResultStat(
                      label: 'TIME',
                      value: _formatTime(_elapsedSeconds),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      label: 'MOVES',
                      value: _moves.toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ResultStat(
                      label: 'PIECES',
                      value: (_columns * _rows).toString(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _sourceBytes = null;
                      _activeImagePath = null;
                      _pieces = [];
                      _board = [];
                      _moves = 0;
                      _elapsedSeconds = 0;
                      _hasStarted = false;
                    });
                  },
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Find another puzzle'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Enjoy the finished picture',
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

  Future<void> _persistActivePuzzle() async {
    final path = _activeImagePath;
    if (path == null || _sourceBytes == null || _board.isEmpty) return;

    final placed = <int>[];
    for (var index = 0; index < _board.length; index++) {
      if (_board[index] != null) placed.add(index);
    }

    final data = <String, dynamic>{
      'imagePath': path,
      'title': _puzzleTitle,
      'columns': _columns,
      'rows': _rows,
      'seed': _shapeSeed,
      'moves': _moves,
      'elapsedSeconds': _elapsedSeconds,
      'placedIndexes': placed,
    };

    try {
      await _preferences.setString(_saveKey, jsonEncode(data));
      if (mounted) {
        setState(() {
          _savedPuzzle = _SavedPuzzle(
            imagePath: path,
            title: _puzzleTitle,
            columns: _columns,
            rows: _rows,
            seed: _shapeSeed,
            moves: _moves,
            elapsedSeconds: _elapsedSeconds,
            placedIndexes: placed,
          );
        });
      }
    } catch (_) {
      // Saving is best-effort and must not interrupt the active game.
    }
  }

  Future<void> _showHint() async {
    final bytes = _sourceBytes;
    if (bytes == null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'A little reminder',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                    color: _muted,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(
                  bytes,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Use the full picture as your guide.',
                style: TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1300),
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
                ? _HomeScreen(
                    savedPuzzle: _savedPuzzle,
                    onPickImage: _pickImage,
                    onOpenLibrary: _openLibrary,
                    onResume: _resumeSavedPuzzle,
                  )
                : _PuzzleView(
                    title: _puzzleTitle,
                    pieces: _pieces,
                    board: _board,
                    columns: _columns,
                    rows: _rows,
                    aspectRatio: _sourceAspectRatio,
                    shapeSeed: _shapeSeed,
                    moves: _moves,
                    elapsedSeconds: _elapsedSeconds,
                    onPickImage: _pickImage,
                    onRestart: _restartPuzzle,
                    onHint: _showHint,
                    onChangeDifficulty: _changeDifficulty,
                    onPlacePiece: _onPlacePiece,
                  ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _lime,
              borderRadius: BorderRadius.all(Radius.circular(22)),
            ),
            child: SizedBox(
              width: 68,
              height: 68,
              child: Icon(Icons.extension_rounded, color: _forest, size: 34),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _forest,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Putting the pieces together…',
            style: TextStyle(color: _muted, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.savedPuzzle,
    required this.onPickImage,
    required this.onOpenLibrary,
    required this.onResume,
  });

  final _SavedPuzzle? savedPuzzle;
  final VoidCallback onPickImage;
  final VoidCallback onOpenLibrary;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: _forest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: _lime,
                  size: 24,
                ),
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
              const Icon(Icons.spa_outlined, color: _forest, size: 23),
            ],
          ),
          const SizedBox(height: 39),
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
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _forest,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: _forest.withOpacity(0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: CustomPaint(
                painter: const PuzzleArtworkPainter(puzzleArtworks[0]),
                child: const SizedBox(width: double.infinity, height: 205),
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (savedPuzzle != null) ...[
            InkWell(
              onTap: onResume,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0DD),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFD8E2C7)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_fill_rounded,
                      color: _forest,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pick up where you left off',
                            style: TextStyle(
                              color: _ink,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            savedPuzzle!.title +
                                ' · ' +
                                savedPuzzle!.placedIndexes.length.toString() +
                                ' pieces placed',
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: _forest,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 13),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPickImage,
              icon: const Icon(Icons.add_photo_alternate_rounded, size: 21),
              label: const Text('Create from my photo'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenLibrary,
              icon: const Icon(Icons.auto_awesome_mosaic_rounded, size: 20),
              label: const Text('Explore the puzzle collection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _forest,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Color(0xFFC8D1C4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 23),
          const Row(
            children: [
              Expanded(
                child: _HomeFeature(
                  icon: Icons.extension_rounded,
                  title: 'Real puzzle pieces',
                  subtitle: 'Tabs and sockets that fit',
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _HomeFeature(
                  icon: Icons.favorite_border_rounded,
                  title: 'Made for moments',
                  subtitle: 'Your photos stay yours',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Free to play. No ads. Just a little joy.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeFeature extends StatelessWidget {
  const _HomeFeature({
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
          Icon(icon, color: _forest, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: _muted, fontSize: 9),
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
    required this.title,
    required this.pieces,
    required this.board,
    required this.columns,
    required this.rows,
    required this.aspectRatio,
    required this.shapeSeed,
    required this.moves,
    required this.elapsedSeconds,
    required this.onPickImage,
    required this.onRestart,
    required this.onHint,
    required this.onChangeDifficulty,
    required this.onPlacePiece,
  });

  final String title;
  final List<PuzzlePiece> pieces;
  final List<PuzzlePiece?> board;
  final int columns;
  final int rows;
  final double aspectRatio;
  final int shapeSeed;
  final int moves;
  final int elapsedSeconds;
  final VoidCallback onPickImage;
  final VoidCallback onRestart;
  final VoidCallback onHint;
  final ValueChanged<int> onChangeDifficulty;
  final void Function(PuzzlePiece piece, int targetIndex) onPlacePiece;

  @override
  Widget build(BuildContext context) {
    final total = columns * rows;
    final solved = total - pieces.length;
    final progress = solved / total;
    final availableBoardWidth =
        min(MediaQuery.sizeOf(context).width - 64, 500.0);
    final coreWidth = availableBoardWidth / (1 + 0.48 / columns);
    final cellWidth = coreWidth / columns;
    final cellHeight = coreWidth / aspectRatio / rows;
    final marginX = cellWidth * 0.24;
    final marginY = cellHeight * 0.24;
    final boardWidth = coreWidth + marginX * 2;
    final boardHeight = coreWidth / aspectRatio + marginY * 2;
    final tileAspectRatio = aspectRatio * rows / columns;
    final trayCols = min(columns + 1, 4);
    final trayCoreWidth = min(
      (MediaQuery.sizeOf(context).width - 100 - (trayCols - 1) * 8) /
          trayCols,
      58.0,
    );
    final trayCoreHeight = trayCoreWidth / tileAspectRatio;
    final shapes = generatePuzzleShapes(columns, rows, seed: shapeSeed);

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'JIGSAW',
                      style: TextStyle(
                        color: _ink,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                    Text(
                      title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              _RoundAction(
                icon: Icons.lightbulb_outline_rounded,
                tooltip: 'Preview the original picture',
                onPressed: onHint,
              ),
              const SizedBox(width: 7),
              _RoundAction(
                icon: Icons.refresh_rounded,
                tooltip: 'Restart puzzle',
                onPressed: onRestart,
              ),
              const SizedBox(width: 7),
              _RoundAction(
                icon: Icons.photo_library_outlined,
                tooltip: 'Choose another photo',
                onPressed: onPickImage,
              ),
            ],
          ),
          const SizedBox(height: 25),
          const Text(
            'PUZZLE IN PROGRESS',
            style: TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.45,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Stay in the flow.',
            style: TextStyle(
              color: _ink,
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _GameStat(
                  icon: Icons.timer_outlined,
                  label: 'TIME',
                  value: _formatTime(elapsedSeconds),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _GameStat(
                  icon: Icons.touch_app_outlined,
                  label: 'MOVES',
                  value: moves.toString(),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _GameStat(
                  icon: Icons.extension_rounded,
                  label: 'LEFT',
                  value: pieces.length.toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(19),
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
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 420),
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
          const SizedBox(height: 20),
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
          const SizedBox(height: 9),
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
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 14, 11, 13),
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
                      'Drop pieces where they belong',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _PuzzleBoard(
                  pieces: board,
                  columns: columns,
                  rows: rows,
                  shapes: shapes,
                  width: boardWidth,
                  height: boardHeight,
                  cellWidth: cellWidth,
                  cellHeight: cellHeight,
                  marginX: marginX,
                  marginY: marginY,
                  onPlacePiece: onPlacePiece,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                    spacing: 8,
                    runSpacing: 9,
                    children: pieces.map((piece) {
                      return _DraggablePiece(
                        piece: piece,
                        coreWidth: trayCoreWidth,
                        coreHeight: trayCoreHeight,
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

class _PuzzleBoard extends StatefulWidget {
  const _PuzzleBoard({
    required this.pieces,
    required this.columns,
    required this.rows,
    required this.shapes,
    required this.width,
    required this.height,
    required this.cellWidth,
    required this.cellHeight,
    required this.marginX,
    required this.marginY,
    required this.onPlacePiece,
  });

  final List<PuzzlePiece?> pieces;
  final int columns;
  final int rows;
  final List<PuzzleShape> shapes;
  final double width;
  final double height;
  final double cellWidth;
  final double cellHeight;
  final double marginX;
  final double marginY;
  final void Function(PuzzlePiece piece, int targetIndex) onPlacePiece;

  @override
  State<_PuzzleBoard> createState() => _PuzzleBoardState();
}

class _PuzzleBoardState extends State<_PuzzleBoard> {
  final GlobalKey _boardKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return DragTarget<PuzzlePiece>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final renderObject = _boardKey.currentContext?.findRenderObject();
        if (renderObject is! RenderBox) return;

        final local = renderObject.globalToLocal(details.offset);
        final column =
            ((local.dx - widget.marginX) / widget.cellWidth).floor();
        final row =
            ((local.dy - widget.marginY) / widget.cellHeight).floor();

        if (column < 0 ||
            column >= widget.columns ||
            row < 0 ||
            row >= widget.rows) {
          return;
        }

        final targetIndex = row * widget.columns + column;
        if (widget.pieces[targetIndex] != null) return;
        widget.onPlacePiece(details.data, targetIndex);
      },
      builder: (context, candidates, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EDE4),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: candidates.isNotEmpty ? _forest : const Color(0xFFD8DFD3),
              width: candidates.isNotEmpty ? 2 : 1,
            ),
          ),
          child: ClipRRect(
            key: _boardKey,
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PuzzleBoardPainter(
                      columns: widget.columns,
                      rows: widget.rows,
                      shapes: widget.shapes,
                      marginX: widget.marginX,
                      marginY: widget.marginY,
                      backgroundColor: const Color(0xFFE9EDE4),
                      lineColor: const Color(0xFFB8C5B8),
                    ),
                  ),
                ),
                for (var index = 0; index < widget.pieces.length; index++)
                  if (widget.pieces[index] != null)
                    Positioned(
                      left: widget.marginX +
                          (index % widget.columns) * widget.cellWidth -
                          widget.pieces[index]!.coreRect.left *
                              (widget.cellWidth /
                                  widget.pieces[index]!.coreRect.width),
                      top: widget.marginY +
                          (index ~/ widget.columns) * widget.cellHeight -
                          widget.pieces[index]!.coreRect.top *
                              (widget.cellHeight /
                                  widget.pieces[index]!.coreRect.height),
                      width: widget.cellWidth /
                          widget.pieces[index]!.coreRect.width,
                      height: widget.cellHeight /
                          widget.pieces[index]!.coreRect.height,
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('placed-' + index.toString()),
                        tween: Tween<double>(begin: 0.82, end: 1),
                        duration: const Duration(milliseconds: 210),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: JigsawPieceImage(
                          bytes: widget.pieces[index]!.imageBytes,
                          shape: widget.pieces[index]!.shape,
                          coreRect: widget.pieces[index]!.coreRect,
                        ),
                      ),
                    ),
                if (candidates.isNotEmpty)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _lime.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DraggablePiece extends StatelessWidget {
  const _DraggablePiece({
    required this.piece,
    required this.coreWidth,
    required this.coreHeight,
  });

  final PuzzlePiece piece;
  final double coreWidth;
  final double coreHeight;

  @override
  Widget build(BuildContext context) {
    final width = coreWidth / piece.coreRect.width;
    final height = coreHeight / piece.coreRect.height;
    return Draggable<PuzzlePiece>(
      data: piece,
      maxSimultaneousDrags: 1,
      feedback: Material(
        color: Colors.transparent,
        elevation: 8,
        child: SizedBox(
          width: width * 1.08,
          height: height * 1.08,
          child: JigsawPieceImage(
            bytes: piece.imageBytes,
            shape: piece.shape,
            coreRect: piece.coreRect,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.18,
        child: SizedBox(
          width: width,
          height: height,
          child: JigsawPieceImage(
            bytes: piece.imageBytes,
            shape: piece.shape,
            coreRect: piece.coreRect,
          ),
        ),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: JigsawPieceImage(
          bytes: piece.imageBytes,
          shape: piece.shape,
          coreRect: piece.coreRect,
        ),
      ),
    );
  }
}

class _GameStat extends StatelessWidget {
  const _GameStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: _forest),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 7),
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: _forest,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
            width: 38,
            height: 38,
            child: Icon(icon, color: _forest, size: 19),
          ),
        ),
      ),
    );
  }
}

String _formatTime(int seconds) {
  final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
  final remainder = (seconds % 60).toString().padLeft(2, '0');
  return minutes + ':' + remainder;
}
