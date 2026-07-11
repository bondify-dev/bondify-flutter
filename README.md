# bondify_flutter

Flutter SDK для аутентификации через Telegram (Bondify).

## Установка

```yaml
# pubspec.yaml
dependencies:
  bondify_flutter:
    git:
      url: https://github.com/bondify/bondify-flutter
      ref: v1.0.0
  url_launcher: ^6.2.4
  # Опционально — для настоящего QR-кода:
  # qr_flutter: ^4.1.0
```

## Быстрый старт

```dart
// main.dart
import 'package:bondify_flutter/bondify_flutter.dart';

void main() {
  BondifyClient.init(BondifyConfig(
    projectId: 'proj_xxxxxxxxxxxxxx',
    apiUrl: 'https://api.bondify.dev',
  ));
  runApp(MyApp());
}
```

## BondifyButton — drop-in кнопка

```dart
BondifyButton(
  label: 'Войти через Telegram',
  onSuccess: (user) {
    print('ID: ${user.telegramId}');
    print('Proof: ${user.proof}');
    // Отправьте proof на ваш бэкенд для верификации
  },
)
```

## showBondifyAuthSheet — bottom sheet с QR

```dart
ElevatedButton(
  onPressed: () => showBondifyAuthSheet(
    context,
    onSuccess: (user) => Navigator.pushNamed(context, '/home'),
  ),
  child: Text('Войти'),
)
```

## BondifyStatusBuilder — реактивный UI

```dart
BondifyStatusBuilder(
  builder: (context, state) => switch (state.status) {
    BondifyAuthStatus.confirmed => HomePage(user: state.user!),
    BondifyAuthStatus.polling   => LoadingPage(secondsLeft: state.secondsLeft),
    _                           => LoginPage(),
  },
)
```

## Прямое управление

```dart
final client = BondifyClient.instance;

// Запустить и открыть Telegram
await client.startAuth();
if (client.deeplink != null) {
  await launchUrl(Uri.parse(client.deeplink!),
    mode: LaunchMode.externalApplication);
}

// Сброс
client.reset();
```

## Настройка платформы (Android)

Пакет открывает Telegram-диплинк через `url_launcher` с
`LaunchMode.externalApplication`. На Android 11+ (API 30+) система по
умолчанию скрывает от приложения информацию об установленных пакетах
(package visibility) — без явного объявления `<queries>` вызов
`launchUrl`/`canLaunchUrl` для внешнего приложения может не сработать.

Добавьте в `android/app/src/main/AndroidManifest.xml`:

```xml
<queries>
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>
  <package android:name="org.telegram.messenger" />
</queries>
```

iOS дополнительной настройки не требует — диплинк это обычная `https://t.me/…`
ссылка (Universal Link), а не кастомная схема, так что `LSApplicationQueriesSchemes`
в `Info.plist` не нужен.

## Верификация proof на бэкенде

```dart
// После получения user.proof — отправьте его на ваш Node.js бэкенд:
final response = await http.post(
  Uri.parse('https://your-api.com/auth/verify'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'proof': user.proof}),
);
// Бэкенд: bondify.verifyProof(proof) → { telegram_id, telegram_name, ... }
```

## С QR-кодом (qr_flutter)

```dart
// Если установлен qr_flutter, можно самому показать QR:
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
