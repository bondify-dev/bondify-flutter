# Bondify Flutter SDK

One-tap **Telegram authentication** for Flutter apps. No SMS, no passwords — your
users tap a button, confirm in Telegram, and you get a verified identity.

[![pub package](https://img.shields.io/pub/v/bondify_flutter.svg)](https://pub.dev/packages/bondify_flutter)

- 🔘 Drop-in `BondifyButton` and `showBondifyAuthSheet`
- 📱 Built for mobile — uses the public, key-less flow (your secret key never ships in the app)
- 🔒 Returns a signed `proof` (JWT) you verify on your backend
- 🎨 Themeable (Telegram / dark / light), with built-in loading & success states
- 🪶 Tiny: only `http` and `url_launcher`

---

## Installation

Add the package to your `pubspec.yaml`.

**From pub.dev** (once published):

```yaml
dependencies:
  bondify_flutter: ^1.0.0
```

**From GitHub** (before it's on pub.dev):

```yaml
dependencies:
  bondify_flutter:
    git:
      url: https://github.com/bondify/bondify-flutter
      ref: v1.0.0
```

Then:

```bash
flutter pub get
```

> **Before you start:** open your [Bondify dashboard](https://docs.bondify.dev),
> copy your **Project ID** (`proj_…`), and enable **Mobile SDK** in the project
> settings. The mobile flow uses public endpoints that only work when Mobile SDK
> is on.

---

## Quick start

### 1. The login button

```dart
import 'package:bondify_flutter/bondify_flutter.dart';

BondifyButton(
  projectId: 'proj_xxxxxxxx',
  label: 'Login with Telegram',
  theme: BondifyTheme.telegram, // telegram | dark | light
  onSuccess: (user) {
    // user.proof is a signed JWT — send it to YOUR backend and verify it.
    debugPrint('Welcome, ${user.name} (@${user.username})');
  },
  onError: (err) => debugPrint('Login failed: $err'),
)
```

### 2. Or a guided bottom sheet

```dart
final user = await showBondifyAuthSheet(context, projectId: 'proj_xxxxxxxx');
if (user != null) {
  // signed in
}
```

### 3. Or drive the flow yourself

```dart
final client = BondifyClient(const BondifyConfig(projectId: 'proj_xxxxxxxx'));

try {
  final user = await client.authenticate(
    onStatus: (s) => debugPrint('status: $s'),
  );
  debugPrint('Signed in as ${user.telegramId}');
} on BondifyException catch (e) {
  debugPrint('Auth error: ${e.message}');
}
```

You can also configure a singleton once at startup and omit `projectId` everywhere:

```dart
void main() {
  BondifyClient.init(const BondifyConfig(projectId: 'proj_xxxxxxxx'));
  runApp(const MyApp());
}
```

---

## Verify the proof on your backend (required)

The SDK runs on the user's device, so **never trust it alone**. Always send
`user.proof` to your server and verify it there before creating a session.

`proof` is a JWT signed (HS256) with your project's **webhook secret**
(`whsec_…`, found in your project settings). Verify it with any JWT library:

```js
// Node.js (Express) example
import jwt from 'jsonwebtoken'

app.post('/auth/telegram', (req, res) => {
  const { proof } = req.body
  try {
    const claims = jwt.verify(proof, process.env.BONDIFY_WEBHOOK_SECRET) // whsec_…
    // claims = { telegram_id, telegram_name, telegram_username, project_id, ... }
    // → create or look up the user, issue your own session cookie/JWT
    res.json({ ok: true, telegramId: claims.telegram_id })
  } catch {
    res.status(401).json({ error: 'Invalid proof' })
  }
})
```

> Keep `BONDIFY_WEBHOOK_SECRET` on the server only. It is **not** the same as your
> `secret_key` and must never be shipped in the app.

---

## Platform setup

`url_launcher` opens the Telegram app. On Android 11+ declare the query so the
launch check works:

**`android/app/src/main/AndroidManifest.xml`** (inside `<queries>`):

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <package android:name="org.telegram.messenger" />
</queries>
```

iOS works out of the box; no extra configuration is required for `https://t.me`
links.

---

## API reference

### `BondifyButton`

| Property       | Type                          | Default                  | Description                                  |
| -------------- | ----------------------------- | ------------------------ | -------------------------------------------- |
| `projectId`    | `String?`                     | uses `BondifyClient`     | Your Project ID. Omit if you called `init()`.|
| `onSuccess`    | `void Function(BondifyUser)`  | —                        | Called with the verified user.               |
| `onError`      | `void Function(Object)?`      | `null`                   | Called on failure/cancel.                    |
| `label`        | `String`                      | `'Login with Telegram'`  | Idle button text.                            |
| `theme`        | `BondifyTheme`                | `telegram`               | `telegram` / `dark` / `light`.               |
| `borderRadius` | `double`                      | `14`                     | Corner radius.                               |
| `expand`       | `bool`                        | `false`                  | Full-width button.                           |
| `apiBase`      | `String?`                     | hosted API               | Advanced / self-hosted.                      |

### `BondifyUser`

| Field         | Type      | Description                                       |
| ------------- | --------- | ------------------------------------------------- |
| `telegramId`  | `String`  | Stable numeric Telegram ID.                       |
| `name`        | `String`  | Display name.                                     |
| `username`    | `String?` | `@username` if set (no leading `@`).              |
| `phone`       | `String?` | Only if your project collects phone numbers.      |
| `proof`       | `String`  | Signed JWT — verify on your backend.              |
| `confirmedAt` | `int`     | Confirmation time (ms since epoch).               |

### `BondifyClient`

- `Future<GenerateResponse> startSession()`
- `Future<void> openTelegram(String deeplink)`
- `Future<BondifyUser> waitForConfirmation(token, {onStatus, cancelToken})`
- `Future<BondifyUser> authenticate({onStatus, cancelToken})` — full flow

---

## Example

A complete runnable example lives in [`example/`](example/lib/main.dart):

```bash
cd example
flutter run
```

---

## License

MIT © Bondify
