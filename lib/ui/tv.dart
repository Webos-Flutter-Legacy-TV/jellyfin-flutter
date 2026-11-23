// TV building blocks: everything the remote can reach is a TvFocusable, which shows the
// mockups' focus (white ring, blue halo, a small lift) and activates on OK / Enter.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

typedef FocusBuilder = Widget Function(BuildContext context, bool focused);

class TvFocusable extends StatefulWidget {
  final FocusBuilder builder;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onFocus;
  final bool autofocus;
  final FocusNode? focusNode;
  final double scale; // lift when focused
  final bool ensureVisible;

  const TvFocusable({super.key, required this.builder, this.onPressed, this.onFocus, this.autofocus = false, this.focusNode, this.scale = 1.0, this.ensureVisible = true});

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  bool _focused = false;
  FocusNode? _ownNode;
  FocusNode get _node => widget.focusNode ?? (_ownNode ??= FocusNode());
  // Focus that came from the Magic Remote pointer: no scrolling to centre the
  // element, or the row would slide away from under the pointer.
  bool _fromPointer = false;

  @override
  void dispose() {
    _ownNode?.dispose();
    super.dispose();
  }

  // onHover fires only when the pointer itself moves, not when content scrolls
  // under a resting pointer, so remote-key navigation is not disturbed.
  void _onHover(PointerHoverEvent e) {
    if (_node.hasFocus || !_node.canRequestFocus) return;
    _fromPointer = true;
    _node.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent || widget.onPressed == null) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.numpadEnter || k == LogicalKeyboardKey.space) {
      widget.onPressed!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.builder(context, _focused);
    if (widget.scale != 1.0) {
      child = AnimatedScale(scale: _focused ? widget.scale : 1.0, duration: const Duration(milliseconds: 140), curve: Curves.easeOut, child: child);
    }
    return Focus(
      focusNode: _node,
      autofocus: widget.autofocus,
      onKeyEvent: _onKey,
      onFocusChange: (f) {
        setState(() => _focused = f);
        widget.onFocus?.call(f);
        final fromPointer = _fromPointer;
        _fromPointer = false;
        if (f && widget.ensureVisible && !fromPointer) {
          Scrollable.ensureVisible(context, alignment: 0.5, alignmentPolicy: ScrollPositionAlignmentPolicy.explicit, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
        }
      },
      child: MouseRegion(onHover: _onHover, child: GestureDetector(onTap: widget.onPressed, child: child)),
    );
  }
}

/// A rounded button: white when focused (or `primary`), translucent otherwise.
class PillButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool autofocus;
  final bool primary;
  final double height;
  final FocusNode? focusNode;
  final String? tooltip;

  const PillButton({super.key, this.label, this.icon, this.onPressed, this.autofocus = false, this.primary = false, this.height = 76, this.focusNode, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final round = label == null;
    return Semantics(
      button: true,
      label: label ?? tooltip,
      child: TvFocusable(
        autofocus: autofocus,
        focusNode: focusNode,
        onPressed: onPressed,
        ensureVisible: false,
        builder: (context, focused) {
          final bg = focused ? Colors.white : (primary ? const Color(0xEBFFFFFF) : const Color(0x24FFFFFF));
          final fg = focused || primary ? Palette.ground : Colors.white;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: height,
            width: round ? height : null,
            padding: round ? null : EdgeInsets.symmetric(horizontal: height * 0.48),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(height), boxShadow: focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 6)] : null),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) Icon(icon, color: fg, size: height * 0.38),
              if (icon != null && label != null) SizedBox(width: height * 0.18),
              if (label != null) Text(label!, style: tv(height * 0.35, weight: FontWeight.w700, color: fg)),
            ]),
          );
        },
      ),
    );
  }
}

/// A text field that fits the TV: tall, dark, accent border when focused.
class TvTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction action;

  const TvTextField({super.key, required this.controller, required this.label, this.hint, this.obscure = false, this.autofocus = false, this.focusNode, this.onSubmitted, this.action = TextInputAction.next});

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late final FocusNode _node = widget.focusNode ?? FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() => _focused = _node.hasFocus));
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.label, style: tv(22, color: _focused ? Palette.accentText : Palette.text2)),
      const SizedBox(height: 10),
      AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 80,
        padding: const EdgeInsets.symmetric(horizontal: 26),
        decoration: BoxDecoration(
          color: Palette.field,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _focused ? Colors.white : Palette.fieldBorder, width: _focused ? 3 : 2),
          boxShadow: _focused ? [const BoxShadow(color: Palette.focusGlow, spreadRadius: 6)] : null,
        ),
        alignment: Alignment.centerLeft,
        child: TextField(
          controller: widget.controller,
          focusNode: _node,
          autofocus: widget.autofocus,
          obscureText: widget.obscure,
          textInputAction: widget.action,
          onSubmitted: widget.onSubmitted,
          style: tv(27),
          cursorColor: Palette.accent,
          decoration: InputDecoration(border: InputBorder.none, isCollapsed: true, hintText: widget.hint, hintStyle: tv(27, color: Palette.text3)),
        ),
      ),
    ]);
  }
}

/// Small rounded label: "4K", "DOLBY VISION", "PG-13".
class Badge2 extends StatelessWidget {
  final String text;
  final bool outlined;
  const Badge2(this.text, {super.key, this.outlined = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: outlined ? 8 : 12, vertical: outlined ? 1 : 5),
        decoration: BoxDecoration(
          color: outlined ? null : const Color(0x24FFFFFF),
          border: outlined ? Border.all(color: const Color(0x73FFFFFF), width: 2) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text, style: tv(outlined ? 20 : 18, weight: outlined ? FontWeight.w600 : FontWeight.w700, spacing: outlined ? null : 0.5)),
      );
}

/// Loading / error / empty state in the middle of a page.
class StateMessage extends StatelessWidget {
  final String title;
  final String? detail;
  final Widget? action;
  final bool loading;
  const StateMessage({super.key, required this.title, this.detail, this.action, this.loading = false});
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (loading) const Padding(padding: EdgeInsets.only(bottom: 28), child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5, color: Palette.accent))),
          Text(title, style: tv(36, weight: FontWeight.w600), textAlign: TextAlign.center),
          if (detail != null) Padding(padding: const EdgeInsets.only(top: 14), child: SizedBox(width: 900, child: Text(detail!, style: tv(24, color: Palette.text2, height: 1.45), textAlign: TextAlign.center))),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 32), child: action!),
        ]),
      );
}
