# Jigsaw Puzzle

A free, offline-first Flutter jigsaw puzzle game for Android and iOS. Turn personal photos or original built-in artwork into a puzzle, then put the pieces back together.

## Features

- **Real jigsaw geometry:** Interlocking tabs and sockets with matching neighbouring edges.
- **Your own photos:** Choose an image from the device photo library.
- **A small offline collection:** Four original illustrated scenes are included in the app and work without downloading content.
- **Three challenges:** Easy (9 pieces), Medium (16 pieces), and Hard (25 pieces).
- **Picture hint:** Preview the complete image while solving.
- **Game stats:** Track elapsed time, moves, remaining pieces, and completion progress.
- **Animated feedback:** Pieces animate into place and the board highlights while a piece is dragged over it.
- **Resume later:** The active image and puzzle progress are saved locally on the device.
- **Private by design:** Photos and save data stay in app-private local storage. There are no accounts, ads, subscriptions, or paid features.

## Run locally

Install the Flutter SDK, then run:

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

On Android or iOS, grant photo-library access when prompted. Built-in puzzles can be played without granting photo-library access.

## Local save data

The active photo is stored in the app's private documents directory. Puzzle dimensions, placed-piece indexes, timer, and move count are stored locally and used to restore the active game after the app is closed. Removing the app or clearing its application data removes the local save.

## Project structure

- `lib/main.dart` — game flow, UI, photo selection, timer, and local save/restore.
- `lib/puzzle_logic.dart` — puzzle dimensions and deterministic complementary edge generation.
- `lib/jigsaw_piece.dart` — piece clipping paths and board-slot painting.
- `lib/puzzle_library.dart` — original vector artwork and the built-in puzzle collection.
- `test/puzzle_logic_test.dart` — puzzle dimension and edge-geometry tests.

## Project values

Jigsaw Puzzle is intended as a small gift: free to play, with no ads and no paid features.
