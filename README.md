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

## Android builds through GitHub Actions

No Android SDK is needed on a developer's computer to produce Android builds. Every push to `main`, pull request, or manual workflow dispatch runs the Flutter checks and then builds:

- A debug APK for direct device testing.
- A release APK.
- A Google Play Android App Bundle (`.aab`).

Open the repository's **Actions** tab, select **Flutter checks and Android builds**, open a successful run, and download the artifacts at the bottom of the run summary.

The debug APK is signed with the standard debug key and is suitable for installation and testing. The release APK and App Bundle are unsigned until the Play upload key is configured.

### Play signing

Do not commit a keystore or `android/key.properties`. To enable signed release builds, add these repository Actions secrets:

- `ANDROID_KEYSTORE_BASE64` — Base64-encoded upload keystore.
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The workflow decodes the keystore only on the ephemeral GitHub runner and writes a temporary `android/key.properties`. When the secrets are absent, the debug APK and unsigned release candidates can still be built.

**Before the first Play Store submission:** replace the current placeholder Android application ID, `com.example.jigsaw_puzzle`, with the permanent unique package ID chosen for the Play listing. Do this before publishing; future updates must keep the same application ID.

## Project structure

- `lib/main.dart` — game flow, UI, photo selection, timer, and local save/restore.
- `lib/puzzle_logic.dart` — puzzle dimensions and deterministic complementary edge generation.
- `lib/jigsaw_piece.dart` — piece clipping paths and board-slot painting.
- `lib/puzzle_library.dart` — original vector artwork and the built-in puzzle collection.
- `test/puzzle_logic_test.dart` — puzzle dimension and edge-geometry tests.

## Project values

Jigsaw Puzzle is intended as a small gift: free to play, with no ads and no paid features.
