// Magic Remote edge scrolling: while the pointer rests near the left or right
// end of a horizontal row, the row scrolls that way, faster the closer the
// pointer is to the end. Stops when the pointer leaves the edge strip or the
// row, at the end of the row, or on any remote key (webOS hides the pointer
// when a key is pressed).
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class EdgeScroll extends StatefulWidget {
  /// Builds the horizontal scrollable; it must use the given controller.
  final Widget Function(BuildContext context, ScrollController controller) builder;

  /// Width of the strip at each end that scrolls the row, in logical pixels.
  final double edge;

  /// Speed at the very end of the row, in logical pixels per second.
  final double maxSpeed;

  const EdgeScroll({super.key, required this.builder, this.edge = 220, this.maxSpeed = 2400});

  @override
  State<EdgeScroll> createState() => _EdgeScrollState();
}

class _EdgeScrollState extends State<EdgeScroll> with SingleTickerProviderStateMixin {
  final _controller = ScrollController();
  late final Ticker _ticker = createTicker(_tick);
  double _velocity = 0; // px/s, negative = towards the start
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _onKey(KeyEvent e) {
    if (e is KeyDownEvent) _stop();
    return false; // never consume keys
  }

  void _onHover(PointerHoverEvent e) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final x = box.globalToLocal(e.position).dx;
    final w = box.size.width;
    final edge = widget.edge.clamp(1.0, w / 3);
    // A third of the top speed on entering the strip, full speed at the end.
    double speed(double depth) => widget.maxSpeed * (0.35 + 0.65 * depth.clamp(0.0, 1.0));
    double v = 0;
    if (x < edge) {
      v = -speed(1 - x / edge);
    } else if (x > w - edge) {
      v = speed(1 - (w - x) / edge);
    }
    _velocity = v;
    if (v != 0 && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (v == 0) {
      _stop();
    }
  }

  void _stop() {
    _velocity = 0;
    if (_ticker.isActive) _ticker.stop();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!_controller.hasClients || dt <= 0 || dt > 0.1) return;
    final p = _controller.position;
    final target = (p.pixels + _velocity * dt).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (target == p.pixels) {
      _stop(); // reached the end of the row
      return;
    }
    p.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
        opaque: false,
        onHover: _onHover,
        onExit: (_) => _stop(),
        child: widget.builder(context, _controller),
      );
}
