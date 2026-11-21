// The right-hand panel from mockups 8 and 9: the page dims, a panel slides in from the
// right, Back closes it. Rows are big TV targets with an optional check or radio.
import 'package:flutter/material.dart';

import '../theme.dart';
import 'tv.dart';

Future<T?> showSidePanel<T>(BuildContext context, {required WidgetBuilder builder, double width = 720}) {
  return Navigator.of(context).push<T>(PageRouteBuilder<T>(
    opaque: false,
    barrierDismissible: true,
    barrierColor: const Color(0x8C000000),
    transitionDuration: const Duration(milliseconds: 200),
    reverseTransitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: const Color(0xF70F1219),
        child: SizedBox(width: width, height: double.infinity, child: FocusTraversalGroup(child: builder(context))),
      ),
    ),
    transitionsBuilder: (context, anim, _, child) => SlideTransition(
      position: Tween(begin: const Offset(0.25, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: FadeTransition(opacity: anim, child: child),
    ),
  ));
}

class PanelHeader extends StatelessWidget {
  final String? kicker;
  final String title;
  const PanelHeader({super.key, this.kicker, required this.title});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (kicker != null) Text(kicker!.toUpperCase(), style: tv(20, weight: FontWeight.w600, color: Palette.text3, spacing: 1.5)),
          const SizedBox(height: 4),
          Text(title, style: tv(38, weight: FontWeight.w700)),
        ]),
      );
}

class PanelSection extends StatelessWidget {
  final String label;
  const PanelSection(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 0, 6),
        child: Text(label.toUpperCase(), style: tv(18, weight: FontWeight.w700, color: const Color(0x73FFFFFF), spacing: 2)),
      );
}

/// One choice: title, optional detail and tag; `selected` shows a filled radio.
class PanelRow extends StatelessWidget {
  final String title;
  final String? detail, tag;
  final bool? selected; // null: no radio
  final bool danger, autofocus;
  final IconData? icon;
  final VoidCallback onPressed;

  const PanelRow({super.key, required this.title, this.detail, this.tag, this.selected, this.danger = false, this.autofocus = false, this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TvFocusable(
          autofocus: autofocus,
          onPressed: onPressed,
          builder: (context, focused) {
            final fg = focused ? Palette.ground : (danger ? Palette.danger : Colors.white);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 110),
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: detail == null ? 18 : 16),
              decoration: BoxDecoration(
                color: focused ? Colors.white : (selected == true ? Palette.surfaceRaised : Colors.transparent),
                borderRadius: BorderRadius.circular(14),
                boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 5)] : null,
              ),
              child: Row(children: [
                if (selected != null) ...[
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fg, width: 3)),
                    child: selected! ? Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: fg)) : null,
                  ),
                  const SizedBox(width: 20),
                ] else if (icon != null) ...[
                  Icon(icon, color: focused ? Palette.ground : (danger ? Palette.danger : Palette.text2), size: 28),
                  const SizedBox(width: 20),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: tv(25, weight: FontWeight.w600, color: fg)),
                    if (detail != null) ...[
                      const SizedBox(height: 4),
                      Text(detail!, style: tv(19, color: focused ? const Color(0xB30B0D12) : Palette.text3)),
                    ],
                  ]),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0x3300A4DC), borderRadius: BorderRadius.circular(6)),
                    child: Text(tag!, style: tv(16, weight: FontWeight.w700, color: focused ? Palette.ground : Palette.accentText)),
                  ),
              ]),
            );
          },
        ),
      );
}

/// "Are you sure?" as a small panel; resolves to true when confirmed.
Future<bool> confirmPanel(BuildContext context, {required String title, required String detail, required String confirm}) async {
  final ok = await showSidePanel<bool>(
    context,
    width: 640,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(56, 90, 56, 56),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PanelHeader(title: title),
        Text(detail, style: tv(24, color: Palette.text2, height: 1.5)),
        const SizedBox(height: 40),
        PanelRow(title: 'Cancel', autofocus: true, onPressed: () => Navigator.of(context).pop(false)),
        PanelRow(title: confirm, danger: true, onPressed: () => Navigator.of(context).pop(true)),
      ]),
    ),
  );
  return ok == true;
}
