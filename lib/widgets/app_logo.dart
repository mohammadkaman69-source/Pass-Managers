import 'package:flutter/material.dart';

/// Reusable NexVault / Pass Managers logo.
/// Pure UI widget — no security or data dependencies.
class AppLogo extends StatelessWidget {
  final double height;
  final double? width;
  final BoxFit fit;
  final bool showShadow;

  const AppLogo({
    super.key,
    this.height = 96,
    this.width,
    this.fit = BoxFit.contain,
    this.showShadow = false,
  });

  /// Compact version for AppBars and lists (uses icon_small asset).
  const AppLogo.small({
    super.key,
    this.height = 28,
    this.width,
    this.fit = BoxFit.contain,
    this.showShadow = false,
  });

  String get _assetPath {
    // Prefer the dedicated small icon for compact UI.
    if (height <= 40) {
      return 'assets/icon/icon_small.png';
    }
    return 'assets/logo/nexvault_logo.png';
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        // Fallback chain so the app never crashes if an asset is missing.
        return Image.asset(
          'assets/logo/nexvault_logo.png',
          height: height,
          width: width,
          fit: fit,
          errorBuilder: (_, __, ___) => Icon(
            Icons.lock_outline,
            size: height * 0.7,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
    );

    if (!showShadow) {
      return image;
    }

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: image,
    );
  }
}
