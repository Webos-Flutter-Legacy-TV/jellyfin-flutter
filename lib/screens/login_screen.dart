// Mockup 2 · Sign in: Quick Connect (code shown big, signs in by itself once approved) beside
// the user name and password form.
import 'dart:async';

import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../session.dart';
import '../theme.dart';
import '../ui/tv.dart';

class LoginScreen extends StatefulWidget {
  final Session session;
  const LoginScreen({super.key, required this.session});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _passNode = FocusNode();
  QuickConnectState? _qc;
  bool? _qcEnabled;
  String? _qcError, _formError;
  bool _busy = false;
  Timer? _poll;

  JellyfinClient get _client => widget.session.client!;

  @override
  void initState() {
    super.initState();
    _user.text = widget.session.current?.userName ?? '';
    _startQuickConnect();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _startQuickConnect() async {
    _poll?.cancel();
    try {
      final enabled = await _client.quickConnectEnabled();
      if (!mounted) return;
      setState(() => _qcEnabled = enabled);
      if (!enabled) return;
      final qc = await _client.quickConnectInitiate();
      if (!mounted) return;
      setState(() {
        _qc = qc;
        _qcError = null;
      });
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } on ApiException catch (e) {
      if (mounted) setState(() => _qcError = e.message);
    }
  }

  Future<void> _check() async {
    final qc = _qc;
    if (qc == null) return;
    try {
      final now = await _client.quickConnectPoll(qc.secret);
      if (!now.authenticated) return;
      _poll?.cancel();
      final auth = await _client.authenticateWithQuickConnect(qc.secret);
      await widget.session.signedIn(auth);
    } on ApiException catch (e) {
      // An expired code answers 404: start over with a new one.
      if (e.status == 404) {
        _startQuickConnect();
      } else if (mounted) {
        setState(() => _qcError = e.message);
      }
    }
  }

  Future<void> _signIn() async {
    if (_busy || _user.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final auth = await _client.authenticateByName(_user.text.trim(), _pass.text);
      await widget.session.signedIn(auth);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _formError = e.unauthorized ? 'Wrong user name or password.' : e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = widget.session.current!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.session.leaveServer();
      },
      child: Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: _PosterWall()),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xF50B0D12), Color(0xE60B0D12), Color(0xB30B0D12)], stops: [0, 0.45, 1]),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(140, 110, 140, 90),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(server.name.toUpperCase(), style: tv(22, weight: FontWeight.w600, color: Palette.accentText, spacing: 2)),
              const SizedBox(height: 14),
              Text('Sign in', style: tv(64, weight: FontWeight.w700, spacing: -1)),
              const SizedBox(height: 56),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _quickConnectPanel()),
                  SizedBox(
                    width: 90,
                    child: Column(children: [
                      Expanded(child: Container(width: 2, color: const Color(0x1FFFFFFF))),
                      Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text('OR', style: tv(22, weight: FontWeight.w600, color: Palette.text3))),
                      Expanded(child: Container(width: 2, color: const Color(0x1FFFFFFF))),
                    ]),
                  ),
                  Expanded(child: _passwordPanel()),
                ]),
              ),
              const SizedBox(height: 32),
              Text('Back returns to the server list. Forgot your password? Ask the server\'s administrator.', style: tv(21, color: Palette.text3)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _panel({required Widget child, bool emphasised = false}) => Container(
        padding: const EdgeInsets.all(52),
        decoration: BoxDecoration(
          color: emphasised ? const Color(0xE6151922) : const Color(0xBF151922),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0x0FFFFFFF)),
        ),
        child: child,
      );

  Widget _quickConnectPanel() {
    final qc = _qc;
    return _panel(
      emphasised: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.phone_iphone, color: Palette.accentText, size: 40),
          const SizedBox(width: 16),
          Text('Quick Connect', style: tv(34, weight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(999)),
            child: Text('Recommended', style: tv(20, weight: FontWeight.w600, color: Palette.onAccent)),
          ),
        ]),
        const SizedBox(height: 24),
        if (_qcEnabled == false)
          Text('Quick Connect is turned off on this server. Sign in with your password.', style: tv(25, color: Palette.text2, height: 1.5))
        else ...[
          Text('On your phone or computer, open Jellyfin, go to your profile, then Quick Connect, and enter:', style: tv(25, color: Palette.text2, height: 1.5)),
          const SizedBox(height: 30),
          Row(children: [
            for (final ch in (qc?.code ?? '······').split(''))
              Container(
                width: 92,
                height: 120,
                margin: const EdgeInsets.only(right: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Palette.field, borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.fieldBorder, width: 2)),
                child: Text(ch, style: tv(64, weight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 30),
          Row(children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: _qcError == null ? Palette.accent : Palette.danger, shape: BoxShape.circle),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                _qcError ?? (qc == null ? 'Getting a code…' : 'Waiting for approval · signs in by itself'),
                style: tv(22, color: _qcError == null ? Palette.text2 : Palette.danger),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _passwordPanel() => _panel(
        child: FocusTraversalGroup(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('User name and password', style: tv(34, weight: FontWeight.w600)),
            const SizedBox(height: 24),
            TvTextField(controller: _user, label: 'User', hint: 'Name', autofocus: true, onSubmitted: (_) => _passNode.requestFocus()),
            const SizedBox(height: 20),
            TvTextField(controller: _pass, label: 'Password', hint: 'Password', obscure: true, focusNode: _passNode, action: TextInputAction.done, onSubmitted: (_) => _signIn()),
            const SizedBox(height: 18),
            Text(_formError ?? 'You stay signed in on this TV.', style: tv(22, color: _formError != null ? Palette.danger : Palette.text3)),
            const Spacer(),
            PillButton(label: _busy ? 'Signing in…' : 'Sign in', height: 80, onPressed: _signIn),
          ]),
        ),
      );
}

/// The dim wall of tiles behind the sign-in form (the official app shows the server's splash there).
class _PosterWall extends StatelessWidget {
  const _PosterWall();
  static const _hues = [Color(0xFF3B4A6B), Color(0xFF6B3B3B), Color(0xFF2F5D50), Color(0xFF5D4A2F), Color(0xFF4A2F5D), Color(0xFF2F4D5D), Color(0xFF5D2F45), Color(0xFF4D5D2F), Color(0xFF2F3B5D)];
  @override
  // Tiles carry their own alpha: Opacity over the whole screen is slow on TV GPUs.
  Widget build(BuildContext context) => ClipRect(
        child: Transform.rotate(
          angle: -0.14,
          child: Transform.scale(
            scale: 1.25,
            child: GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 9,
              mainAxisSpacing: 22,
              crossAxisSpacing: 22,
              childAspectRatio: 2 / 3,
              children: [for (var i = 0; i < 45; i++) DecoratedBox(decoration: BoxDecoration(color: _hues[(i * 4) % _hues.length].withValues(alpha: 0.32), borderRadius: BorderRadius.circular(14)))],
            ),
          ),
        ),
      );
}
