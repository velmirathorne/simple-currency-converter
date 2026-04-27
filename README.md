# Simple Currency Converter

A clean, minimal Flutter app for converting between world currencies using live exchange rates.

---

## Features

- **~170 currencies** — select any from/to pair from a searchable dropdown
- **Two-way conversion** — swap the currency pair instantly with one tap, result updates automatically
- **Live rates** — fetched fresh on every launch from the [Frankfurter API](https://www.frankfurter.dev/)
- **Smart formatting** — comma-separated thousands for normal values; scientific notation (`×10^`) for very large or very small results; whole-number formatting for currencies like VND, JPY, and KRW
- **Live rate hint** — shows the unit rate (e.g. `1 USD ≈ 26,241 VND`) below the convert button

---

## Project Structure

```
lib/
├── main.dart              # App entry point and MaterialApp theme
└── home_page.dart         # All converter logic and UI
```

The app is intentionally single-page with no routing or state management library — plain `StatefulWidget` is sufficient for this scope.

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.41.7` *(verified working as of April 2026)*
- Dart SDK `>=3.11.5` *(verified working as of April 2026)*
- An internet connection at runtime *(rates are fetched live)*

### Install & Run

```bash
# Install dependencies
flutter pub get

# Run on a connected device or emulator
flutter run
```

### Build

```bash
# Android APK
flutter build apk --release

# iOS (macOS required)
flutter build ios --release
```

---

## Dependencies

| Package | Version | Purpose |
|---|---|---|
| `http` | `^1.6.0` | HTTP requests to the Frankfurter API |
| `intl` | `^0.20.2` | Number formatting with locale-aware separators |

---

## How It Works

### Rate Fetching

On launch, the app fetches all available exchange rates in a single request using USD as the base:

```
GET https://api.frankfurter.dev/v2/rates?base=USD
```

The v2 API returns a JSON array of objects — `[{"base": "USD", "quote": "EUR", "rate": 0.91}, ...]` — which is parsed into a `Map<String, double>` with `USD: 1.0` added manually (Frankfurter omits the base currency from the response). This map is built once and reused for the lifetime of the session.

### Conversion

Any pair is converted using the cross-rate formula:

```
result = amount × (toRate / fromRate)
```

Both rates are relative to USD, so no additional API calls are needed for non-USD pairs.

### Keyboard Avoidance

A `FocusNode` listener on the text field calls `Scrollable.ensureVisible` with `keepVisibleAtEnd` alignment policy after the next frame callback. This is driven by the actual render object position rather than timers or hardcoded delays, making it consistent across devices and Android versions.

### Performance

Dropdown items (~170 entries) are built once inside `_loadRates()` and stored as a field. They are not rebuilt on `setState`, avoiding a re-sort and re-allocation on every keypress or conversion.

---

## Android Permission

The following permission is required in `android/app/src/main/AndroidManifest.xml` for network access:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## API Attribution

Exchange rates are provided by [Frankfurter](https://www.frankfurter.dev/), a free and open-source API. Rates are sourced from the European Central Bank and updated on business days.
