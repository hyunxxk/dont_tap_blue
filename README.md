# Don't Tap Blue

One-finger reaction game built for a fast mobile launch.

## Concept

Tap the safe targets, dodge the blue traps, and survive as the board gets faster
and more deceptive. The first release is designed to be small enough to ship in a
week and sharp enough to test whether short-form score challenges can drive
downloads.

## Week-One Scope

- Core tap-or-avoid gameplay
- Score, combo, best score, and fail state
- Haptics and simple sound feedback
- Shareable score screen
- iOS-first release path, Android-ready project structure

## Development

```sh
flutter run
```

```sh
flutter test
```

## External Test Build

The Flutter Web build is deployed with GitHub Pages:

```text
https://hyunxxk.github.io/dont_tap_blue/
```

Manual web build:

```sh
flutter build web --release --base-href /dont_tap_blue/
```
