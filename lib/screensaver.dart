// Idle screensaver: after a few minutes without a key press (and not while a video plays),
// backdrops from the user's libraries drift and cross-fade with the title and a clock.
// Any key (or the pointer on the PC preview) wakes it; that key does nothing else.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/models.dart';
import 'session.dart';
import 'theme.dart';
import 'ui/cards.dart';
import 'ui/image_cache.dart';

/// Set by the player while a video is playing, so the screensaver keeps away.
final videoPlaying = ValueNotifier<bool>(false);

class Screensaver extends StatefulWidget {
  final Session session;
  final Widget child;
  const Screensaver({super.key, required this.session, required this.child});
  @override
  State<Screensaver> createState() => _ScreensaverState();
}

class _ScreensaverState extends State<Screensaver> with WidgetsBindingObserver {
  Timer? _idle;
  bool _on = false;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_restart);
    videoPlaying.addListener(_restart);
    _restart();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_restart);
    videoPlaying.removeListener(_restart);
    _idle?.cancel();
    _own.dispose();
    super.dispose();
  }

  /// Any key restarts the idle countdown (the screensaver's own focus node handles waking).
  bool _onKey(KeyEvent e) {
    if (!_on) _restart();
    return false;
  }

  void _restart() {
    _idle?.cancel();
    final mins = widget.session.screensaverMinutes;
    if (mins <= 0 || videoPlaying.value) {
      if (_on && videoPlaying.value) setState(() => _on = false);
      return;
    }
    _idle = Timer(Duration(minutes: mins), () {
      if (!mounted || videoPlaying.value || widget.session.current?.signedIn != true) return;
      _before = FocusManager.instance.primaryFocus;
      setState(() => _on = true);
      WidgetsBinding.instance.addPostFrameCallback((_) => _own.requestFocus());
    });
  }

  FocusNode? _before; // focus to give back on waking
  final _own = FocusNode(debugLabel: 'screensaver');

  void _wake() {
    if (!_on) return;
    setState(() => _on = false);
    final f = _before;
    _before = null;
    if (f != null && f.context != null && f.context!.mounted) f.requestFocus();
    _restart();
  }

  // The TV remote's Back arrives as a route pop: wake instead of leaving the page.
  @override
  Future<bool> didPopRoute() async {
    if (!_on) return false;
    _wake();
    return true;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _wake(),
        onPointerHover: (_) => _restart(),
        child: Stack(children: [
          widget.child,
          if (_on)
            Positioned.fill(
              // Holds focus while shown: the key that wakes it goes nowhere else.
              child: Focus(
                focusNode: _own,
                onKeyEvent: (_, e) {
                  if (e is KeyDownEvent) _wake();
                  return KeyEventResult.handled;
                },
                child: Material(color: Colors.black, child: _Slides(session: widget.session)),
              ),
            ),
        ]),
      );
}

class _Slides extends StatefulWidget {
  final Session session;
  const _Slides({required this.session});
  @override
  State<_Slides> createState() => _SlidesState();
}

class _SlidesState extends State<_Slides> {
  static const _each = Duration(seconds: 12);
  List<Item> _items = const [];
  int _i = 0;
  Timer? _next, _clock;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _shown = true);
    });
  }

  @override
  void dispose() {
    _next?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final client = widget.session.client;
    if (client == null) return;
    try {
      final page = await client.items({
        'recursive': true,
        'includeItemTypes': 'Movie,Series',
        'imageTypes': 'Backdrop',
        'sortBy': 'Random',
        'limit': 30,
        'fields': 'Overview',
        'enableImageTypes': 'Backdrop,Logo',
      });
      if (!mounted) return;
      setState(() => _items = page.items.where((i) => client.backdrop(i) != null).toList());
      _next = Timer.periodic(_each, (_) async {
        if (!mounted || _items.length < 2) return;
        final n = (_i + 1) % _items.length;
        // Switch once the next backdrop is ready, so picture and title change together.
        try {
          await precacheImage(cachedImage(client.backdrop(_items[n])!), context);
        } catch (_) {}
        if (mounted) setState(() => _i = n);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final client = widget.session.client;
    final item = _items.isEmpty ? null : _items[_i];
    final now = TimeOfDay.now().format(context);
    return AnimatedOpacity(
      opacity: _shown ? 1 : 0,
      duration: const Duration(milliseconds: 900),
      child: ColoredBox(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          if (item != null && client != null)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 1600),
              child: _Drift(
                key: ValueKey(item.id),
                // Alternate the drift direction slide to slide.
                reverse: _i.isOdd,
                duration: _each + const Duration(seconds: 2),
                child: NetImage(client.backdrop(item)!, fit: BoxFit.cover),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.center, colors: [Color(0xCC000000), Color(0x00000000)]),
            ),
          ),
          if (item != null && client != null)
            Positioned(
              left: 96,
              bottom: 84,
              right: 700,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
                child: Column(key: ValueKey(item.id), crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  if (client.logo(item) != null)
                    SizedBox(
                      width: 560,
                      height: 150,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: NetImage(client.logo(item)!, fit: BoxFit.contain, fallback: Align(alignment: Alignment.bottomLeft, child: _title(item))),
                      ),
                    )
                  else
                    _title(item),
                  if (item.yearLine != null) ...[const SizedBox(height: 14), Text(item.yearLine!, style: tv(24, color: const Color(0xCCFFFFFF)))],
                ]),
              ),
            ),
          Positioned(
            right: 96,
            bottom: 84,
            child: Text(now, style: tv(64, weight: FontWeight.w300, color: const Color(0xE6FFFFFF), spacing: -1)),
          ),
        ]),
      ),
    );
  }

  Widget _title(Item i) => Text(i.name, style: tv(56, weight: FontWeight.w700, spacing: -1), maxLines: 2, overflow: TextOverflow.ellipsis);
}

/// A slow zoom and pan across the image.
class _Drift extends StatelessWidget {
  final Widget child;
  final bool reverse;
  final Duration duration;
  const _Drift({super.key, required this.child, required this.reverse, required this.duration});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        builder: (context, t, child) => Transform.scale(
          scale: 1.04 + 0.08 * t,
          alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
          child: child,
        ),
        child: SizedBox.expand(child: child),
      );
}
