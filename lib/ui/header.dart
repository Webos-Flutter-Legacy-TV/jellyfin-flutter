// The top bar from the mockups: Jellyfin mark, a pill of tabs (Home and the libraries),
// Search, the user avatar and the clock. Transparent: it sits over the artwork.
import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'logo.dart';
import 'tv.dart';

class HeaderTab {
  final String label;
  final VoidCallback onPressed;
  final bool selected;
  HeaderTab(this.label, this.onPressed, {this.selected = false});
}

class TopHeader extends StatelessWidget {
  final List<HeaderTab> tabs;
  final VoidCallback? onSearch;
  final VoidCallback? onUser;
  final String userInitial;
  final VoidCallback? onBack;
  final String? title;

  const TopHeader({super.key, this.tabs = const [], this.onSearch, this.onUser, this.userInitial = '', this.onBack, this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: Insets.header,
      child: FocusTraversalGroup(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Insets.page),
          child: Row(children: [
            if (onBack != null) ...[
              _RoundIcon(icon: Icons.arrow_back_ios_new, label: 'Back', onPressed: onBack!),
              const SizedBox(width: 24),
            ] else ...[
              const JellyfinMark(size: 52),
              const SizedBox(width: 40),
            ],
            if (title != null) ...[Text(title!, style: tv(40, weight: FontWeight.w700)), const SizedBox(width: 32)],
            if (tabs.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0x8C151922), borderRadius: BorderRadius.circular(999), border: Border.all(color: const Color(0x14FFFFFF))),
                child: Row(children: [for (final t in tabs) _Tab(t)]),
              ),
            const Spacer(),
            if (onSearch != null) _RoundIcon(icon: Icons.search, label: 'Search', onPressed: onSearch!),
            if (onUser != null) ...[
              const SizedBox(width: 20),
              TvFocusable(
                onPressed: onUser,
                ensureVisible: false,
                builder: (context, focused) => Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: const Color(0xFF7A4FB5), shape: BoxShape.circle, boxShadow: focused ? focusShadow(ring: 3) : null),
                  child: Text(userInitial, style: tv(26, weight: FontWeight.w700)),
                ),
              ),
            ],
            const SizedBox(width: 28),
            const _Clock(),
          ]),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final HeaderTab tab;
  const _Tab(this.tab);
  @override
  Widget build(BuildContext context) => TvFocusable(
        onPressed: tab.onPressed,
        ensureVisible: false,
        builder: (context, focused) {
          final on = focused || tab.selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              color: focused ? Colors.white : (tab.selected ? const Color(0x33FFFFFF) : null),
              borderRadius: BorderRadius.circular(999),
              boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 5)] : null,
            ),
            child: Text(tab.label, style: tv(24, weight: FontWeight.w600, color: focused ? Palette.ground : (on ? Colors.white : const Color(0xCCFFFFFF)))),
          );
        },
      );
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _RoundIcon({required this.icon, required this.label, required this.onPressed});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: TvFocusable(
          onPressed: onPressed,
          ensureVisible: false,
          builder: (context, focused) => Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: focused ? Colors.white : const Color(0x8C151922),
              shape: BoxShape.circle,
              boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 6)] : null,
            ),
            child: Icon(icon, size: 30, color: focused ? Palette.ground : Colors.white),
          ),
        ),
      );
}

class _Clock extends StatefulWidget {
  const _Clock();
  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late Timer _t;
  DateTime _now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = _now.hour % 12 == 0 ? 12 : _now.hour % 12;
    final m = _now.minute.toString().padLeft(2, '0');
    return Text('$h:$m ${_now.hour < 12 ? 'AM' : 'PM'}', style: tv(24, weight: FontWeight.w500, color: const Color(0xBFFFFFFF)));
  }
}
