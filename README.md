# SefCG

SefCG is a Flutter application for checking trading card prices, identifying exact card printings, and tracking a digital collection portfolio.

## Current MVP

- Pokemon and Riftbound game selection
- Manual search by card name, collector number, or set using live price APIs
- Exact card detail pages with set, rarity, variant, API price source, and freshness
- OCR-first scanner workflow with candidate fallback
- Collection tab with editable per-card purchase prices and quantities
- Collection net worth, total acquisition cost, and unrealised gain/loss by currency
- Manual market-price refresh preserving purchase costs

Collections are automatically saved to a versioned local file in the app documents directory and restored at startup. Additions, purchase edits, and refreshed prices are saved before success is reported. Failed loads preserve the existing file and offer Retry. Storage is device-local; account sign-in and cloud sync are not implemented. Uninstalling the app or clearing its data can remove the collection. Prices are estimates from the configured providers.

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
