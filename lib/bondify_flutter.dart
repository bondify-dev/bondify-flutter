/// Bondify Flutter SDK
/// One-tap Telegram authentication for Flutter apps.
///
/// Quick start:
/// ```dart
/// import 'package:bondify_flutter/bondify_flutter.dart';
///
/// BondifyButton(
///   projectId: 'proj_xxxxxxxx',
///   onSuccess: (user) {
///     // Send user.proof to YOUR backend and verify it there.
///     debugPrint('Welcome, ${user.name}');
///   },
/// )
/// ```
library bondify_flutter;

export 'src/models/models.dart';
export 'src/client/bondify_client.dart';
export 'src/client/api_client.dart' show GenerateResponse, VerifyResponse;
export 'src/widgets/widgets.dart';
