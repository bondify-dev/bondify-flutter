/// Bondify Flutter SDK
/// Telegram Authentication for Flutter apps
///
/// Использование:
/// ```dart
/// import 'package:bondify_flutter/bondify_flutter.dart';
///
/// void main() {
///   BondifyClient.init(BondifyConfig(projectId: 'proj_xxxxxx'));
///   runApp(MyApp());
/// }
/// ```
library bondify_flutter;

export 'src/models/models.dart';
export 'src/client/bondify_client.dart';
export 'src/client/api_client.dart' show GenerateResponse, VerifyResponse;
export 'src/widgets/widgets.dart';
