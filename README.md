# bondify_flutter

Flutter SDK for Telegram authentication via Bondify.

## Installation

```yaml
# pubspec.yaml
dependencies:
  bondify_flutter: ^1.0.1
  url_launcher: ^6.2.4
  # Optional — for a real QR code:
  # qr_flutter: ^4.1.0
```

## Quick start

```dart
// main.dart
import 'package:bondify_flutter/bondify_flutter.dart';

void main() {
  BondifyClient.init(BondifyConfig(
    projectId: 'proj_xxxxxxxxxxxxxx',
  ));
  runApp(MyApp());
}
```

## BondifyButton — drop-in button

```dart
BondifyButton(
  label: 'Sign in with Telegram',
  onSuccess: (user) {
    print('ID: ${user.telegramId}');
    print('Proof: ${user.proof}');
    // Send proof to your backend for verification
  },
)
```

## showBondifyAuthSheet — bottom sheet with QR

```dart
ElevatedButton(
  onPressed: () => showBondifyAuthSheet(
    context,
    onSuccess: (user) => Navigator.pushNamed(context, '/home'),
  ),
  child: const Text('Sign in'),
)
```

## BondifyStatusBuilder — reactive UI

```dart
BondifyStatusBuilder(
  builder: (context, state) => switch (state.status) {
    BondifyAuthStatus.confirmed => HomePage(user: state.user!),
    BondifyAuthStatus.polling   => LoadingPage(secondsLeft: state.secondsLeft),
    _                           => LoginPage(),
  },
)
```

## Manual control

```dart
final client = BondifyClient.instance;

// Start auth and open Telegram
await client.startAuth();
if (client.deeplink != null) {
  await launchUrl(
    Uri.parse(client.deeplink!),
    mode: LaunchMode.externalApplication,
  );
}

// Reset
client.reset();
```

## Platform setup (Android)

The package opens the Telegram deep link via `url_launcher` with
`LaunchMode.externalApplication`. On Android 11+ (API 30+) the system hides
information about installed packages by default (package visibility) — without
an explicit `<queries>` declaration, `launchUrl`/`canLaunchUrl` for an external
app may silently fail.

Add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <package android:name="org.telegram.messenger" />
</queries>
```

iOS requires no additional setup — the deep link is a standard `https://t.me/…`
Universal Link, so `LSApplicationQueriesSchemes` in `Info.plist` is not needed.

## Verifying the proof on your backend

```dart
// After receiving user.proof — send it to your Node.js backend:
final response = await http.post(
  Uri.parse('https://your-api.com/auth/verify'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'proof': user.proof}),
);
// Backend: bondify.verifyProof(proof) => { telegram_id, telegram_name, ... }
```

## With QR code (qr_flutter)

```dart
// If qr_flutter is installed, you can render the QR yourself:
import 'package:qr_flutter/qr_flutter.dart';

BondifyStatusBuilder(
  builder: (context, state) {
    if (state.status == BondifyAuthStatus.polling && state.deeplink != null) {
      return QrImageView(
        data: state.deeplink!,
        version: QrVersions.auto,
        size: 200,
      );
    }
    return BondifyButton();
  },
)
```
