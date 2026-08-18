# SefCG

SefCG is a Flutter application for checking trading card prices, identifying exact card printings, and tracking a digital collection portfolio.

## Current MVP

- Pokemon and Riftbound game selection
- Manual search by card name, collector number, or set
- Exact card detail pages with set, rarity, variant, price source, and freshness
- OCR-first scanner workflow with candidate fallback
- Local collection portfolio view with acquisition cost, estimated value, and unrealised gain/loss

## Requirements

- Flutter SDK
- Android Studio or Android SDK for Android builds
- Xcode on macOS for iOS builds

## Run

```sh
flutter pub get
flutter run
```

Use `flutter devices` to confirm an emulator, simulator, or physical device is available.

## Verify

```sh
flutter analyze
flutter test
```
