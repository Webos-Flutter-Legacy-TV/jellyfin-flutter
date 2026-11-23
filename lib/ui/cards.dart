// Cards and rows from the mockups: 16:9 cards (Continue watching, Next up, libraries) and
// portrait posters (Recently added, library grids). Focus lifts the card with the ring.
import 'package:flutter/material.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../theme.dart';
import 'image_cache.dart';
import 'tv.dart';
import 'edge_scroll.dart';

/// A network image that fades in and shows a tinted placeholder (with the title) until then.
class NetImage extends StatelessWidget {
  final String? url;
  final String? fallbackText;
  final BoxFit fit;
  final int? cacheWidth;
  /// Shown instead of the tinted placeholder while loading or when the image fails (title logos).
  final Widget? fallback;
  const NetImage(this.url, {super.key, this.fallbackText, this.fit = BoxFit.cover, this.cacheWidth, this.fallback});

  @override
  Widget build(BuildContext context) {
    final placeholder = fallback ?? Container(
      color: Palette.surfaceRaised,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(16),
      child: fallbackText == null ? null : Text(fallbackText!, style: tv(22, weight: FontWeight.w800, color: Palette.text2), maxLines: 3, overflow: TextOverflow.ellipsis),
    );
    if (url == null) return placeholder;
    final provider = cachedImage(url!);
    return Image(
      image: cacheWidth == null ? provider : ResizeImage(provider, width: cacheWidth, policy: ResizeImagePolicy.fit),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 200), child: frame == null ? placeholder : child),
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}

class _Progress extends StatelessWidget {
  final double fraction;
  const _Progress(this.fraction);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          height: 6,
          color: const Color(0x33FFFFFF),
          child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: fraction.clamp(0.0, 1.0), child: Container(color: Palette.accent)),
        ),
      );
}

class _CornerBadge extends StatelessWidget {
  final Item item;
  const _CornerBadge(this.item);
  @override
  Widget build(BuildContext context) {
    final ud = item.userData;
    Widget? child;
    if (ud.played) {
      child = const Icon(Icons.check, color: Colors.white, size: 22);
    } else if ((ud.unplayedItemCount ?? 0) > 0) {
      child = Text('${ud.unplayedItemCount}', style: tv(18, weight: FontWeight.w700));
    }
    if (child == null) return const SizedBox.shrink();
    return Positioned(
      right: 12,
      top: 12,
      child: Container(
        constraints: const BoxConstraints(minWidth: 38),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Palette.accent, borderRadius: BorderRadius.circular(19)),
        child: child,
      ),
    );
  }
}

/// One card: picture, then title and a secondary line.
class MediaCard extends StatelessWidget {
  final Item item;
  final JellyfinClient client;
  final bool landscape;
  final double width;
  final VoidCallback? onPressed;
  final ValueChanged<bool>? onFocus;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? title, subtitle; // override the item's own lines

  const MediaCard({super.key, required this.item, required this.client, this.landscape = false, double? width, this.onPressed, this.onFocus, this.autofocus = false, this.focusNode, this.title, this.subtitle})
      : width = width ?? (landscape ? 384 : 220);

  double get imageHeight => landscape ? width * 9 / 16 : width * 1.5;

  // An episode's card is titled with its series (the official cards do the same).
  String get _title => title ?? (item.isEpisode ? (item.seriesName ?? item.name) : item.name);

  String? get _subtitle => subtitle ?? _defaultSubtitle;

  String? get _defaultSubtitle {
    if (item.isEpisode) {
      final label = item.episodeLabel;
      return [?label, item.name].join(' · ');
    }
    final ud = item.userData;
    final rt = item.runtime;
    if (landscape && ud.playbackPositionTicks > 0 && rt != null) {
      final left = rt - item.position;
      if (left.inMinutes > 0) return '${formatRuntime(left)} left';
    }
    return item.yearLine;
  }

  @override
  Widget build(BuildContext context) {
    final url = landscape ? client.landscape(item, width: (width * 2).round()) : client.primary(item, fillWidth: (width * 1.5).round(), fillHeight: (imageHeight * 1.5).round());
    final pct = item.userData.playedPercentage;
    return SizedBox(
      width: width,
      child: TvFocusable(
        autofocus: autofocus,
        focusNode: focusNode,
        onPressed: onPressed,
        onFocus: onFocus,
        scale: 1.05,
        builder: (context, focused) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: imageHeight,
            width: width,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              // No resting drop shadow: an 18 px blur under every card cost the TV's GPU more than
              // any other part of a frame and is all but invisible on the dark background.
              boxShadow: focused ? focusShadow() : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                NetImage(url, fallbackText: _title, cacheWidth: (width * 1.5).round()),
                if (pct != null && pct > 0 && !item.userData.played) _Progress(pct / 100),
                _CornerBadge(item),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Text(_title, style: tv(23, weight: FontWeight.w600, color: focused ? Colors.white : const Color(0xD9FFFFFF)), maxLines: 1, overflow: TextOverflow.ellipsis),
          if (_subtitle != null) ...[
            const SizedBox(height: 4),
            Text(_subtitle!, style: tv(20, color: Palette.text3), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ]),
      ),
    );
  }
}

/// A titled horizontal row of cards.
class CardRow extends StatelessWidget {
  final String title;
  final List<Item> items;
  final JellyfinClient client;
  final bool landscape;
  final void Function(Item) onOpen;
  final void Function(Item)? onFocusItem;
  /// Inside one series: cards titled "3. Episode name" with the runtime, not the series name.
  final bool episodeNames;

  const CardRow({super.key, required this.title, required this.items, required this.client, required this.onOpen, this.landscape = false, this.onFocusItem, this.episodeNames = false});

  @override
  Widget build(BuildContext context) {
    final cardW = landscape ? 384.0 : 220.0;
    final imgH = landscape ? cardW * 9 / 16 : cardW * 1.5;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: Insets.page), child: Text(title, style: tv(34, weight: FontWeight.w600))),
      const SizedBox(height: 20),
      SizedBox(
        height: imgH + 110,
        child: FocusTraversalGroup(
          child: EdgeScroll(builder: (context, controller) => ListView.separated(
            controller: controller,
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(horizontal: Insets.page, vertical: 14),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 32),
            itemBuilder: (context, i) => MediaCard(
              item: items[i],
              client: client,
              landscape: landscape,
              title: episodeNames ? '${items[i].indexNumber != null ? '${items[i].indexNumber}. ' : ''}${items[i].name}' : null,
              subtitle: episodeNames ? (items[i].runtime == null ? '' : formatRuntime(items[i].runtime!)) : null,
              onPressed: () => onOpen(items[i]),
              onFocus: (f) {
                if (f) onFocusItem?.call(items[i]);
              },
            ),
          )),
        ),
      ),
    ]);
  }
}
