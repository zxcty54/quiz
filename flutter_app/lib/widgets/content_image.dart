import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A picture from the `content_base` collections, bundled inside the app.
///
/// Callers pass the repository-relative path the content already uses
/// (`assets/knowyourbihar/rivers.webp`, `assets/reality_truth/zone_….webp`) and
/// this widget maps it to the copy that ships in the APK under
/// `assets/images/`. Bundling is the point: the artwork renders on a first
/// launch, offline, with no request and no CDN in the path - the same choice
/// the daily science stories made.
///
/// The public CDN mirrors are kept strictly as a fallback, for a build where an
/// image was not bundled or a path the bundle does not carry yet. Both layers
/// fail quietly: images are decoration and never information, so the last
/// resort is [error] - by default nothing at all, which leaves the surrounding
/// layout exactly as it was before images existed. Nothing here can block,
/// throw into the widget tree, or leave a broken-image icon on a card.
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

  /// Repository-relative path in `content_base`, for example
  /// `assets/knowyourbihar/rivers.webp`.
  final String assetPath;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Tint used for the reserved slot while the picture is being decoded.
  final Color? placeholderColor;

  /// What to show once the bundle and every mirror have failed. Defaults to
  /// nothing.
  final Widget? error;

  /// Where the collections' artwork is bundled inside this app.
  static const String bundleFolder = 'assets/images';

  static const String repo = 'zxcty54/content_base';

  /// `assets/knowyourbihar/rivers.webp` ->
  /// `assets/images/knowyourbihar/rivers.webp`.
  ///
  /// Empty when [assetPath] has no collection segment, which callers treat as
  /// "there is no picture".
  String get bundledAsset {
    final path = assetPath.startsWith('/') ? assetPath.substring(1) : assetPath;
    final parts = path.split('/');
    if (parts.length < 3 || parts[0] != 'assets') return '';
    return '$bundleFolder/${parts.sublist(1).join('/')}';
  }

  /// CDN mirrors for the same path, used only when the bundle cannot serve it.
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

  /// Set once the bundled asset turns out to be missing, to fall back to CDN.
  bool _useNetwork = false;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    _urls = ContentImage.mirrorsFor(widget.assetPath);
  }

  @override
  void didUpdateWidget(covariant ContentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recycled list tile can hand this state a different picture; start over.
    if (oldWidget.assetPath != widget.assetPath) {
      _urls = ContentImage.mirrorsFor(widget.assetPath);
      _index = 0;
      _useNetwork = false;
      _retryScheduled = false;
    }
  }

  Widget get _placeholder => Container(
        width: widget.width,
        height: widget.height,
        color: widget.placeholderColor ?? const Color(0x14808080),
      );

  /// Both fallbacks are discovered while the tree is being built, so the retry
  /// is queued for after the frame instead of calling setState mid-build. One
  /// step per attempt, then it gives up quietly.
  Widget _fallBack(VoidCallback advance) {
    if (!_retryScheduled) {
      _retryScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _retryScheduled = false;
        if (!mounted) return;
        setState(advance);
      });
    }
    return _placeholder;
  }

  Widget _clip(Widget child) {
    final radius = widget.borderRadius;
    if (radius == null) return child;
    return ClipRRect(borderRadius: radius, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final bundled = widget.bundledAsset;

    // First choice: the copy inside the APK. No network, no cache, no latency.
    if (!_useNetwork && bundled.isNotEmpty) {
      return _clip(
        Image.asset(
          bundled,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: (context, error, stackTrace) =>
              _fallBack(() => _useNetwork = true),
        ),
      );
    }

    // Second choice: walk the public mirrors, caching whatever answers to disk.
    if (_index < _urls.length) {
      return _clip(
        CachedNetworkImage(
          imageUrl: _urls[_index],
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) => _placeholder,
          errorWidget: (context, url, error) => _fallBack(() => _index++),
        ),
      );
    }

    return widget.error ?? const SizedBox.shrink();
  }
}
