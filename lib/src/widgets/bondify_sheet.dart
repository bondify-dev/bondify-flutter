// lib/src/widgets/bondify_sheet.dart
// A modal bottom sheet that walks the user through Telegram login. Useful when
// you want a guided "Continue with Telegram" experience instead of an inline
// button.

import 'package:flutter/material.dart';

import '../models/models.dart';
import 'bondify_button.dart';

/// Shows a bottom sheet with a Bondify login button.
///
/// ```dart
/// final user = await showBondifyAuthSheet(context, projectId: 'proj_xxx');
/// if (user != null) { /* signed in */ }
/// ```
///
/// Returns the [BondifyUser] on success, or `null` if dismissed.
Future<BondifyUser?> showBondifyAuthSheet(
  BuildContext context, {
  String? projectId,
  String? apiBase,
  String title = 'Sign in',
  String subtitle = 'Authenticate securely with your Telegram account.',
  BondifyTheme theme = BondifyTheme.telegram,
}) {
  return showModalBottomSheet<BondifyUser>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _BondifyAuthSheet(
      projectId: projectId,
      apiBase: apiBase,
      title: title,
      subtitle: subtitle,
      theme: theme,
    ),
  );
}

class _BondifyAuthSheet extends StatelessWidget {
  final String? projectId;
  final String? apiBase;
  final String title;
  final String subtitle;
  final BondifyTheme theme;

  const _BondifyAuthSheet({
    this.projectId,
    this.apiBase,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + media.viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          BondifyButton(
            projectId: projectId,
            apiBase: apiBase,
            theme: theme,
            expand: true,
            onSuccess: (user) => Navigator.of(context).pop(user),
            onError: (_) {/* keep sheet open so the user can retry */},
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[500])),
          ),
        ],
      ),
    );
  }
}
