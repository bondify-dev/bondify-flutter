// lib/src/widgets/bondify_button.dart
// Drop-in "Login with Telegram" button. Handles the whole flow: creates a
// session, opens Telegram, polls, and calls onSuccess with the verified user.

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../client/bondify_client.dart';
import 'telegram_icon.dart';

/// Visual theme for [BondifyButton].
enum BondifyTheme { telegram, dark, light }

class BondifyButton extends StatefulWidget {
  /// Your Bondify Project ID. If omitted, uses `BondifyClient.instance`.
  final String? projectId;

  /// Called with the verified user once login is confirmed.
  final void Function(BondifyUser user) onSuccess;

  /// Called if login fails or is cancelled.
  final void Function(Object error)? onError;

  /// Override the API base (advanced / self-hosted).
  final String? apiBase;

  /// Button label in the idle state.
  final String label;

  /// Visual theme.
  final BondifyTheme theme;

  /// Corner radius.
  final double borderRadius;

  /// Full-width button.
  final bool expand;

  const BondifyButton({
    super.key,
    this.projectId,
    required this.onSuccess,
    this.onError,
    this.apiBase,
    this.label = 'Login with Telegram',
    this.theme = BondifyTheme.telegram,
    this.borderRadius = 14,
    this.expand = false,
  });

  @override
  State<BondifyButton> createState() => _BondifyButtonState();
}

class _BondifyButtonState extends State<BondifyButton>
    with SingleTickerProviderStateMixin {
  _BtnState _state = _BtnState.idle;
  String? _statusText;
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;
  BondifyCancelToken? _cancel;
  BondifyClient? _ownClient;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(_pulse);
  }

  @override
  void dispose() {
    _cancel?.cancel();
    _ownClient?.close();
    _pulse.dispose();
    super.dispose();
  }

  BondifyClient _resolveClient() {
    if (widget.projectId != null) {
      _ownClient ??= BondifyClient(BondifyConfig(
        projectId: widget.projectId!,
        apiBase: widget.apiBase ?? 'https://api.bondify.dev',
      ));
      return _ownClient!;
    }
    return BondifyClient.instance;
  }

  Future<void> _start() async {
    if (_state != _BtnState.idle) return;
    setState(() {
      _state = _BtnState.loading;
      _statusText = 'Opening Telegram…';
    });

    try {
      final client = _resolveClient();
      _cancel = BondifyCancelToken();
      final session = await client.startSession();
      await client.openTelegram(session.deeplink);

      if (!mounted) return;
      setState(() {
        _state = _BtnState.waiting;
        _statusText = 'Waiting for confirmation…';
      });

      final user = await client.waitForConfirmation(
        session.sessionToken,
        cancelToken: _cancel,
        onStatus: (s) {
          if (s == BondifyStatus.pending && mounted) {
            setState(() => _statusText = 'Tap the button in Telegram');
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _state = _BtnState.success;
        _statusText = null;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      widget.onSuccess(user);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _state = _BtnState.idle;
        _statusText = null;
      });
      widget.onError?.call(err);
    }
  }

  void _cancelFlow() {
    _cancel?.cancel();
    setState(() {
      _state = _BtnState.idle;
      _statusText = null;
    });
  }

  ({Color bg, Color fg}) _colors() {
    switch (widget.theme) {
      case BondifyTheme.telegram:
        return (bg: const Color(0xFF229ED9), fg: Colors.white);
      case BondifyTheme.dark:
        return (bg: const Color(0xFF1A1A1A), fg: Colors.white);
      case BondifyTheme.light:
        return (bg: Colors.white, fg: const Color(0xFF1A1A1A));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _colors();
    final success = _state == _BtnState.success;
    final busy = _state == _BtnState.loading || _state == _BtnState.waiting;

    final button = GestureDetector(
      onTap: _state == _BtnState.idle ? _start : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        width: widget.expand ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: success
              ? const Color(0xFF22C55E)
              : (_state == _BtnState.idle ? c.bg : c.bg.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.theme == BondifyTheme.light
              ? Border.all(color: const Color(0x14000000))
              : null,
          boxShadow: _state == _BtnState.idle && widget.theme != BondifyTheme.light
              ? [
                  BoxShadow(
                    color: c.bg.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: c.fg),
                ),
              )
            else if (success)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(Icons.check, color: c.fg, size: 20),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: BondifyTelegramIcon(color: c.fg),
              ),
            Text(
              success
                  ? 'Signed in!'
                  : busy
                      ? 'Waiting…'
                      : widget.label,
              style: TextStyle(
                color: c.fg,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        if (_statusText != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_state == _BtnState.waiting) ...[
                FadeTransition(
                  opacity: _pulseAnim,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: c.bg,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                _statusText!,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              if (_state == _BtnState.waiting) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _cancelFlow,
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

enum _BtnState { idle, loading, waiting, success }
