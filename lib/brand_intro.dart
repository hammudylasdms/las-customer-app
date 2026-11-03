import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Loads the portal immediately while iOS plays the bundled, skippable intro.
class BrandedEntry extends StatefulWidget {
  const BrandedEntry({super.key, required this.child});
  final Widget child;
  @override
  State<BrandedEntry> createState() => _BrandedEntryState();
}

class _BrandedEntryState extends State<BrandedEntry> {
  bool showIntro = true;
  bool started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (Platform.isIOS && !reducedMotion) {
          await const MethodChannel(
            'com.lastoptechnik/brand_intro',
          ).invokeMethod<void>('play');
        }
      } on PlatformException {
        // An unavailable video must never block access to the portal.
      } on MissingPluginException {
        // Non-iOS builds retain the static launch branding.
      } finally {
        if (mounted) setState(() => showIntro = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (showIntro)
        Positioned.fill(
          child: Image.asset(
            'assets/branding/login_background.png',
            fit: BoxFit.cover,
          ),
        ),
    ],
  );
}
