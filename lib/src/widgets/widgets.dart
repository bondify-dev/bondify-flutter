// ============================================================
//  bondify_flutter — Widgets
//  BondifyButton, BondifyAuthSheet, BondifyStatusBuilder
// ============================================================

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../client/bondify_client.dart';
import '../models/models.dart';

// ─── BondifyButton ────────────────────────────────────────────────────────────

/// Drop-in "Sign in with Telegram" button.
/// Automatically starts a session and opens Telegram.
///
/// ```dart
/// BondifyButton(
///   onSuccess: (user) => print('Hello, ${user.telegramName}!'),
/// )
/// ```
class BondifyButton extends StatefulWidget {
  final String              label;
  final bool                showIcon;
  final double              borderRadius;
  final Color               backgroundColor;
  final Color               foregroundColor;
  final EdgeInsetsGeometry  padding;
  final TextStyle?          textStyle;
  final void Function(BondifyUser user)?     onSuccess;
  final void Function(BondifyException e)?   onError;

  const BondifyButton({
    super.key,
    this.label           = 'Sign in with Telegram',
    this.showIcon        = true,
    this.borderRadius    = 12,
    this.backgroundColor = const Color(0xFF2AABEE),
    this.foregroundColor = Colors.white,
    this.padding         = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.textStyle,
    this.onSuccess,
    this.onError,
  });

  @override
  State<BondifyButton> createState() => _BondifyButtonState();
}

class _BondifyButtonState extends State<BondifyButton> {
  late final BondifyClient _client;
  void Function(BondifyUser user)?     _previousOnSuccess;
  void Function(BondifyException e)?   _previousOnError;

  @override
  void initState() {
    super.initState();
    _client = BondifyClient.instance;
    // Save whatever was set before us (e.g. by another widget instance, or
    // set directly by the app) so we can restore it on dispose instead of
    // leaving these callbacks permanently pointed at a disposed widget.
    _previousOnSuccess = _client.onSuccess;
    _previousOnError   = _client.onError;
    if (widget.onSuccess != null) _client.onSuccess = widget.onSuccess;
    if (widget.onError   != null) _client.onError   = widget.onError;
    _client.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _client.removeListener(_onStateChange);
    // Only restore if we're still the active callback — if some other
    // widget mounted after us and overwrote it again, don't clobber theirs.
    if (widget.onSuccess != null && identical(_client.onSuccess, widget.onSuccess)) {
      _client.onSuccess = _previousOnSuccess;
    }
    if (widget.onError != null && identical(_client.onError, widget.onError)) {
      _client.onError = _previousOnError;
    }
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  Future<void> _handleTap() async {
    if (_client.isLoading) return;
    await _client.startAuth();
    final deeplink = _client.deeplink;
    if (deeplink != null && mounted) {
      await launchUrl(Uri.parse(deeplink), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading   = _client.isLoading;
    final isConfirmed = _client.isAuthenticated;

    return ElevatedButton(
      onPressed: isLoading || isConfirmed ? null : _handleTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.backgroundColor,
        foregroundColor: widget.foregroundColor,
        padding:         widget.padding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
        elevation: 0,
        disabledBackgroundColor: widget.backgroundColor.withOpacity(0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading) ...[
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.foregroundColor,
              ),
            ),
            const SizedBox(width: 10),
          ] else if (widget.showIcon) ...[
            _TelegramIcon(color: widget.foregroundColor),
            const SizedBox(width: 10),
          ],
          Text(
            isLoading   ? 'Creating session...' :
            isConfirmed ? 'Signed in'            :
                          widget.label,
            style: widget.textStyle ?? TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w600,
              color:      widget.foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BondifyAuthSheet ────────────────────────────────────────────────────────

/// Bottom sheet with QR placeholder and auth status.
///
/// ```dart
/// showBondifyAuthSheet(context, onSuccess: (user) { ... });
/// ```
class BondifyAuthSheet extends StatefulWidget {
  final void Function(BondifyUser user)?   onSuccess;
  final void Function(BondifyException e)? onError;
  final String title;

  const BondifyAuthSheet({
    super.key,
    this.onSuccess,
    this.onError,
    this.title = 'Sign in with Telegram',
  });

  @override
  State<BondifyAuthSheet> createState() => _BondifyAuthSheetState();
}

class _BondifyAuthSheetState extends State<BondifyAuthSheet> {
  late final BondifyClient _client;
  void Function(BondifyUser user)?     _previousOnSuccess;
  void Function(BondifyException e)?   _previousOnError;
  late final void Function(BondifyUser user) _ownOnSuccess;

  @override
  void initState() {
    super.initState();
    _client = BondifyClient.instance;
    _client.addListener(_onStateChange);
    // Save whatever was set before us (e.g. a BondifyButton that opened
    // this sheet) so we can restore it on dispose instead of leaving it
    // pointed at this sheet's (by-then-unmounted) callback.
    _previousOnSuccess = _client.onSuccess;
    _previousOnError   = _client.onError;
    _ownOnSuccess = (user) {
      widget.onSuccess?.call(user);
      if (mounted) Navigator.of(context).pop();
    };
    _client.onSuccess = _ownOnSuccess;
    _client.onError = widget.onError;
    // Start auth immediately after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _client.startAuth());
  }

  @override
  void dispose() {
    _client.removeListener(_onStateChange);
    // Only restore if we're still the active callback — if some other
    // widget took over after us, don't clobber theirs.
    if (identical(_client.onSuccess, _ownOnSuccess)) {
      _client.onSuccess = _previousOnSuccess;
    }
    if (identical(_client.onError, widget.onError)) {
      _client.onError = _previousOnError;
    }
    super.dispose();
  }

  void _onStateChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left:   24,
        right:  24,
        top:    20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Text(
            widget.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          // Content by status
          _buildContent(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_client.status) {
      case BondifyAuthStatus.pending:
        return const _LoadingState(message: 'Creating session...');

      case BondifyAuthStatus.polling:
        return _PollingState(
          deeplink:    _client.deeplink,
          secondsLeft: _client.secondsLeft,
          onOpenTelegram: () async {
            if (_client.deeplink != null) {
              await launchUrl(
                Uri.parse(_client.deeplink!),
                mode: LaunchMode.externalApplication,
              );
            }
          },
        );

      case BondifyAuthStatus.confirmed:
        return _SuccessState(user: _client.user!);

      case BondifyAuthStatus.error:
      case BondifyAuthStatus.expired:
      case BondifyAuthStatus.cancelled:
        return _ErrorState(
          status:  _client.status,
          error:   _client.error,
          onRetry: () => _client.startAuth(),
        );

      case BondifyAuthStatus.idle:
        return const _LoadingState(message: 'Initialising...');
    }
  }
}

// ─── BondifyStatusBuilder ────────────────────────────────────────────────────

/// Reactive builder — rebuilds whenever the auth status changes.
///
/// ```dart
/// BondifyStatusBuilder(
///   builder: (context, state) => switch (state.status) {
///     BondifyAuthStatus.confirmed => HomePage(user: state.user!),
///     _ => LoginPage(),
///   },
/// )
/// ```
class BondifyStatusBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, BondifyAuthState state) builder;

  const BondifyStatusBuilder({super.key, required this.builder});

  @override
  State<BondifyStatusBuilder> createState() => _BondifyStatusBuilderState();
}

class _BondifyStatusBuilderState extends State<BondifyStatusBuilder> {
  late final BondifyClient _client;

  @override
  void initState() {
    super.initState();
    _client = BondifyClient.instance;
    _client.addListener(_rebuild);
  }

  @override
  void dispose() {
    _client.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.builder(context, _client.state);
}

// ─── Internal state widgets ──────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  final String message;
  const _LoadingState({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        const CircularProgressIndicator(color: Color(0xFF2AABEE)),
        const SizedBox(height: 16),
        Text(message, style: TextStyle(color: Colors.grey[600])),
      ],
    ),
  );
}

class _PollingState extends StatelessWidget {
  final String?      deeplink;
  final int?         secondsLeft;
  final VoidCallback onOpenTelegram;

  const _PollingState({
    required this.deeplink,
    required this.secondsLeft,
    required this.onOpenTelegram,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // QR placeholder (use qr_flutter for a real QR code)
        Container(
          width: 180, height: 180,
          decoration: BoxDecoration(
            border:       Border.all(color: const Color(0xFF2AABEE), width: 2),
            borderRadius: BorderRadius.circular(12),
            color:        Colors.grey[50],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _TelegramIcon(color: Color(0xFF2AABEE), size: 48),
              const SizedBox(height: 8),
              Text(
                'Tap the button\nbelow',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (secondsLeft != null)
          Text(
            'Link valid for ${_formatSeconds(secondsLeft!)}',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onOpenTelegram,
            icon: const _TelegramIcon(color: Colors.white),
            label: const Text('Open Telegram'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2AABEE),
              foregroundColor: Colors.white,
              padding:         const EdgeInsets.symmetric(vertical: 14),
              shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tap the "Sign in" button in the bot',
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  static String _formatSeconds(int s) {
    final m = s ~/ 60;
    final r = s % 60;
    return m > 0 ? '${m}m ${r.toString().padLeft(2, '0')}s' : '${s}s';
  }
}

class _SuccessState extends StatelessWidget {
  final BondifyUser user;
  const _SuccessState({required this.user});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Column(
      children: [
        const Text('Signed in',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(user.telegramName,
          style: const TextStyle(fontSize: 16, color: Color(0xFF1c1c1e))),
        if (user.telegramUsername != null)
          Text('@${user.telegramUsername}',
            style: TextStyle(fontSize: 14, color: Colors.grey[500])),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final BondifyAuthStatus status;
  final BondifyException? error;
  final VoidCallback      onRetry;

  const _ErrorState({
    required this.status,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = status == BondifyAuthStatus.cancelled;
    final isExpired   = status == BondifyAuthStatus.expired;

    final title = isCancelled
        ? 'Sign-in cancelled'
        : isExpired
            ? 'Link expired'
            : 'Sign-in failed';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (error != null) ...[
            const SizedBox(height: 6),
            Text(
              error!.message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.red),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2AABEE),
                foregroundColor: Colors.white,
                padding:         const EdgeInsets.symmetric(vertical: 14),
                shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Try again'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Telegram icon ───────────────────────────────────────────────────────────

class _TelegramIcon extends StatelessWidget {
  final Color  color;
  final double size;
  const _TelegramIcon({this.color = Colors.white, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.telegram, color: color, size: size);
  }
}

// ─── Sheet helper ────────────────────────────────────────────────────────────

Future<void> showBondifyAuthSheet(
  BuildContext context, {
  void Function(BondifyUser user)?   onSuccess,
  void Function(BondifyException e)? onError,
  String                             title = 'Sign in with Telegram',
}) {
  return showModalBottomSheet(
    context:            context,
    isScrollControlled: true,
    backgroundColor:    Colors.transparent,
    builder: (_) => BondifyAuthSheet(
      onSuccess: onSuccess,
      onError:   onError,
      title:     title,
    ),
  );
}
