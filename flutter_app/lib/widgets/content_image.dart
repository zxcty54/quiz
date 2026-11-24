import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A remote image from the `zxcty54/content_base` repository.
///
/// It follows the same mirror discipline the app already uses for JSON: walk a
/// list of public CDNs and settle on the first that serves the bytes, which
/// `cached_network_image` then keeps on disk, so an image costs one download
/// and never a second request on later launches.
///
/// These images are decoration, never information, so every failure mode
/// degrades to [error] - by default nothing at all, which leaves the
/// surrounding layout exactly as it was before images existed. Nothing here can
/// block, throw into the widget tree, or leave a broken-image icon on a card.
class ContentImage extends StatefulWidget {
  const ContentImage({
    super.key,
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderColor,
    this.error,
  });

  /// Repository-relative path, for example
  /// `assets/knowyourbihar/rivers.webp` or
  /// `assets/reality_truth/zone_paani_doodh_drinks.webp`.
  final String assetPath;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Tint used for the reserved slot while the bytes are in flight.
  final Color? placeholderColor;

  /// What to show once every mirror has failed. Defaults to nothing.
  final Widget? error;

  static const String repo = 'zxcty54/content_base';

  /// CDN mirrors for a repository-relative path, ordered for binary delivery.
  ///
  /// The Cloudflare content proxy is deliberately absent: it is the door for
  /// the repository's JSON and expects an app-key header, while these CDNs
  /// serve plain bytes with no header and cache them at the edge.
  static List<String> mirrorsFor(String assetPath) {
    final path = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
    if (path.isEmpty) return const <String>[];
    return <String>[
      'https://fastly.jsdelivr.net/gh/$repo@main/$path',
      'https://cdn.jsdelivr.net/gh/$repo@main/$path',
      'https://raw.githack.com/$repo/main/$path',
      'https://cdn.statically.io/gh/$repo/main/$path',
      'https://raw.githubusercontent.com/$repo/refs/heads/main/$path',
    ];
  }

  @override
  State<ContentImage> createState() => _ContentImageState();
}

class _ContentImageState extends State<ContentImage> {
  late List<String> _urls;
  int _index = 0;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    _urls = ContentImage.mirrorsFor(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant ContentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled list tile can hand this state a different image; start over.
    if (oldWidget.assetPath != widget.assetPath) {
      _urls = ContentImage.mirrorsFor(widget.assetPath);
      _index = 0;
      _retryScheduled = false;
    }
  }

  Widget get _placeholder => Container(
        width: widget.width,
        height: widget.height,
        color: widget.placeholderColor ?? const Color(0x14808080),
      );

  /// Called while the widget tree is being built, so the retry is queued for
  /// after the frame instead of calling setState mid-build. One retry per
  /// mirror, then it gives up quietly.
  Widget _onError() {
    if (_index + 1 < _urls.length) {
      if (!_retryScheduled) {
        _retryScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _retryScheduled = false;
          if (!mounted) return;
          setState(() => _index++);
        });
      }
      return _placeholder;
    }
    return widget.error ?? const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty) return widget.error ?? const SizedBox.shrink();

    final image = CachedNetworkImage(
      imageUrl: _urls[_index],
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      placeholder: (context, url) => _placeholder,
      errorWidget: (context, url, error) => _onError(),
    );

    final radius = widget.borderRadius;
    if (radius == null) return image;
    return ClipRRect(borderRadius: radius, child: image);
  }
}
