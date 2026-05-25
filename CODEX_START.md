# Don't Tap Blue - Codex Start Brief

## Project

Build a small mobile reaction game called **Don't Tap Blue**.

The goal is to ship a simple, polished first version within one week. The game
should be iOS-first, Android-ready, and small enough to finish without backend,
login, user-generated content, or complex monetization in the first pass.

## Core Game

Players tap safe targets and avoid blue traps.

- Safe targets increase score.
- Blue targets immediately end the run.
- The board gets faster and more deceptive over time.
- The game should be understandable within 5 seconds.
- The score screen should encourage replay and sharing.

## Current Repo

Local path:

```sh
/Users/hyunxxx/Documents/GitHub/dont_tap_blue
```

GitHub repo:

```text
https://github.com/hyunxxk/dont_tap_blue
```

Stack:

- Flutter
- Dart
- iOS and Android project files already generated

## Useful Commands

```sh
flutter test
```

```sh
flutter analyze
```

```sh
flutter run
```

## Next Best Task

Replace the default Flutter counter app in `lib/main.dart` with the first
playable version:

- Start screen
- 3x3 or 4x4 target grid
- Random safe and blue tiles
- Score and best score
- Game-over state
- Restart button
- Haptic feedback where available

Keep the first implementation simple and shippable. Avoid adding ads, purchases,
accounts, backend services, analytics, or extra packages until the core loop is
fun.

## Product Direction

The hook is not "a color tapping game." The hook is:

> Can you keep tapping fast when the game is trying to trick your brain?

Design for short sessions, immediate failure, fast restart, and score-based
challenge clips.

## Done Criteria For First Playable

- App launches on Flutter without runtime errors.
- A player can start, play, fail, and restart.
- Score visibly increases on safe taps.
- Tapping blue reliably ends the game.
- Difficulty increases during a run.
- `flutter test` passes.
- `flutter analyze` has no meaningful issues.
