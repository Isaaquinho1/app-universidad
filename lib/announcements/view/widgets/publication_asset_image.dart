import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:conecta_itt/announcements/announcements.dart';

/// Displays an image stored in the private institutional publications bucket.
///
/// A temporary signed URL is requested when the widget is created or when the
/// underlying asset changes. The bucket itself remains private.
class PublicationAssetImage extends StatefulWidget {
  const PublicationAssetImage({
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholderIcon = Icons.image_outlined,
    super.key,
  });

  final PublicationAsset asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData placeholderIcon;

  @override
  State<PublicationAssetImage> createState() => _PublicationAssetImageState();
}

class _PublicationAssetImageState extends State<PublicationAssetImage> {
  late Future<String> _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _signedUrlFuture = _createSignedUrl();
  }

  @override
  void didUpdateWidget(covariant PublicationAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.asset.storagePath != widget.asset.storagePath ||
        oldWidget.asset.updatedAt != widget.asset.updatedAt) {
      _signedUrlFuture = _createSignedUrl();
    }
  }

  Future<String> _createSignedUrl() {
    return context.read<PublicationAssetRepository>().createSignedUrl(
      widget.asset,
      expiresInSeconds: 3600,
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: borderRadius,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: FutureBuilder<String>(
          future: _signedUrlFuture,
          builder: (context, snapshot) {
            final signedUrl = snapshot.data;

            if (snapshot.connectionState != ConnectionState.done) {
              return _PublicationImagePlaceholder(
                icon: widget.placeholderIcon,
                showProgress: true,
              );
            }

            if (snapshot.hasError ||
                signedUrl == null ||
                signedUrl.trim().isEmpty) {
              return _PublicationImagePlaceholder(
                icon: Icons.broken_image_outlined,
              );
            }

            return CachedNetworkImage(
              imageUrl: signedUrl,
              width: widget.width,
              height: widget.height,
              fit: widget.fit,
              fadeInDuration: const Duration(milliseconds: 180),
              placeholder:
                  (context, _) => _PublicationImagePlaceholder(
                    icon: widget.placeholderIcon,
                    showProgress: true,
                  ),
              errorWidget:
                  (context, _, _) => const _PublicationImagePlaceholder(
                    icon: Icons.broken_image_outlined,
                  ),
            );
          },
        ),
      ),
    );
  }
}

class _PublicationImagePlaceholder extends StatelessWidget {
  const _PublicationImagePlaceholder({
    required this.icon,
    this.showProgress = false,
  });

  final IconData icon;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child:
            showProgress
                ? const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}
