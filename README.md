# SefCG

SefCG is a Flutter application for checking trading card prices, identifying exact card printings, and tracking a digital collection portfolio.

## Current MVP

- Pokemon and Riftbound game selection
- Manual search by card name, collector number, or set using live price APIs
- Exact card detail pages with set, rarity, variant, API price source, and freshness
- OCR-first scanner workflow with candidate fallback
- Local collection portfolio view with acquisition cost, estimated value, and unrealised gain/loss

## Price APIs

- Pokemon prices use the Pokemon TCG API. An API key is optional for higher rate limits:
  `--dart-define=POKEMON_TCG_API_KEY=your_key`
- Riftbound prices use TCG API. The live search endpoint currently requires
  provider authorization/payment headers, so route Riftbound search through a
  backend that can attach those credentials.

Keep production API keys on a backend when this app moves beyond local development.

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
