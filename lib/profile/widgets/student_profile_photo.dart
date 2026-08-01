import 'package:conecta_itt/institutional_profile/institutional_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Displays a private institutional photograph using a temporary signed URL.
///
/// Initials remain visible while no photograph exists or when the private
/// object cannot be loaded.
class StudentProfilePhoto extends StatefulWidget {
  const StudentProfilePhoto({
    required this.profile,
    required this.initials,
    required this.width,
    required this.height,
    required this.borderRadius,
    this.initialsStyle,
    super.key,
  });

  final AppUserProfile profile;
  final String initials;
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final TextStyle? initialsStyle;

  @override
  State<StudentProfilePhoto> createState() => _StudentProfilePhotoState();
}

class _StudentProfilePhotoState extends State<StudentProfilePhoto> {
  Future<String>? _signedUrlFuture;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(StudentProfilePhoto oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.profile.photoPath != widget.profile.photoPath) {
      _loadSignedUrl();
    }
  }

  void _loadSignedUrl() {
    final photoPath = widget.profile.photoPath?.trim();

    if (photoPath == null || photoPath.isEmpty) {
      _signedUrlFuture = null;
      return;
    }

    _signedUrlFuture = context
        .read<StudentProfilePhotoRepository>()
        .createSignedUrl(photoPath, expiresInSeconds: 3600);
  }

  @override
  Widget build(BuildContext context) {
    final signedUrlFuture = _signedUrlFuture;

    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: widget.borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child:
          signedUrlFuture == null
              ? _InitialsFallback(
                initials: widget.initials,
                style: widget.initialsStyle,
              )
              : FutureBuilder<String>(
                future: signedUrlFuture,
                builder: (context, snapshot) {
                  final signedUrl = snapshot.data;

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (snapshot.hasError ||
                      signedUrl == null ||
                      signedUrl.trim().isEmpty) {
                    return _InitialsFallback(
                      initials: widget.initials,
                      style: widget.initialsStyle,
                    );
                  }

                  return Image.network(
                    signedUrl,
                    width: widget.width,
                    height: widget.height,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    gaplessPlayback: true,
                    errorBuilder:
                        (context, error, stackTrace) => _InitialsFallback(
                          initials: widget.initials,
                          style: widget.initialsStyle,
                        ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials, this.style});

  final String initials;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style:
            style ??
            const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}
