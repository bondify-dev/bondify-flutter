import 'package:flutter_test/flutter_test.dart';
import 'package:bondify_flutter/bondify_flutter.dart';

void main() {
  test('BondifyUser.fromJson parses confirmed payload', () {
    final user = BondifyUser.fromJson({
      'telegram_id': 12345,
      'telegram_name': 'Ada Lovelace',
      'telegram_username': 'ada',
      'proof': 'jwt.token.here',
      'confirmed_at': 1700000000000,
    });
    expect(user.telegramId, '12345');
    expect(user.name, 'Ada Lovelace');
    expect(user.username, 'ada');
    expect(user.proof, 'jwt.token.here');
  });

  test('BondifyConfig defaults to hosted API', () {
    const cfg = BondifyConfig(projectId: 'proj_test');
    expect(cfg.apiBase, 'https://api.bondify.dev');
    expect(cfg.pollInterval, const Duration(seconds: 2));
  });

  test('BondifyCancelToken flips on cancel', () {
    final t = BondifyCancelToken();
    expect(t.isCancelled, false);
    t.cancel();
    expect(t.isCancelled, true);
  });
}
