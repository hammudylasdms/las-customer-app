import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'navigation_policy.dart';
import 'push_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final policy = NavigationPolicy(
    Uri.parse(
      const String.fromEnvironment(
        'PORTAL_ORIGIN',
        defaultValue: 'https://dms.lastoptechnik.com',
      ),
    ),
  );
  runApp(
    MaterialApp(
      title: 'LAS Top Technik',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1967ce)),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: PortalApp(policy: policy),
    ),
  );
}

class PortalApp extends StatefulWidget {
  const PortalApp({super.key, required this.policy});
  final NavigationPolicy policy;
  @override
  State<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends State<PortalApp> with WidgetsBindingObserver {
  late final WebViewController controller;
  int progress = 0;
  bool failed = false;
  bool obscured = false;
  bool pushBusy = false;
  static const pushEnabled = bool.fromEnvironment('ENABLE_PUSH');
  late final PushService push;
  final appLinks = AppLinks();
  StreamSubscription<Uri>? links;
  DateTime? backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {
          PlaybackMediaTypes.audio,
          PlaybackMediaTypes.video,
        },
      );
    }
    controller = WebViewController.fromPlatformCreationParams(params);
    push = PushService(controller, widget.policy);
    unawaited(_configure());
  }

  Future<void> _configure() async {
    try {
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      if (pushEnabled) {
        await controller.addJavaScriptChannel(
          'LasPushRegistration',
          onMessageReceived: (message) {
            unawaited(push.registration.receive(message.message));
          },
        );
      }
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            final action = widget.policy.classify(uri);
            if (action == LinkAction.portal) return NavigationDecision.navigate;
            // Hosted checkout embeds HTTPS frames; their cookies remain scoped
            // by the platform browser. External top-level pages open separately.
            if (action == LinkAction.external &&
                !request.isMainFrame &&
                uri.scheme == 'https') {
              return NavigationDecision.navigate;
            }
            if (action == LinkAction.external && request.isMainFrame) {
              try {
                final opened = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!opened) _notice('This link could not be opened.');
              } catch (_) {
                _notice('This link could not be opened.');
              }
            } else if (request.isMainFrame) {
              _notice('This link is not available in the app yet.');
            }
            return NavigationDecision.prevent;
          },
          onProgress: (value) {
            if (mounted) setState(() => progress = value);
          },
          onPageStarted: (_) {
            push.registration.cancelPending();
            if (mounted) setState(() => failed = false);
          },
          onPageFinished: (_) {
            if (pushEnabled) {
              unawaited(push.registerCurrentPage());
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => failed = true);
            }
          },
        ),
      );
      await controller.loadRequest(widget.policy.origin.resolve('/customer'));
      links = appLinks.uriLinkStream.listen((uri) {
        final destination = widget.policy.appDestination(uri);
        if (destination != null) {
          unawaited(
            controller.loadRequest(destination).catchError((Object _) {}),
          );
        }
      }, onError: (Object _) {});
      final initialLink = await appLinks.getInitialLink();
      final destination = initialLink == null
          ? null
          : widget.policy.appDestination(initialLink);
      if (destination != null) await controller.loadRequest(destination);
      if (pushEnabled) {
        try {
          await push.initialise();
        } catch (_) {
          _notice('Notifications are not available yet.');
        }
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void _notice(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _changeNotifications(bool enable) async {
    if (pushBusy) return;
    setState(() => pushBusy = true);
    final result = enable ? await push.enable() : await push.disable();
    if (!mounted) return;
    setState(() => pushBusy = false);
    _notice(switch (result) {
      PushOutcome.enabled =>
        'Notifications are enabled for this customer account.',
      PushOutcome.disabled => 'Notifications are disabled on this device.',
      PushOutcome.permissionDenied =>
        'Allow notifications in your device settings, then try again.',
      PushOutcome.signInRequired =>
        'Sign in to your customer account, then enable notifications.',
      PushOutcome.retry =>
        'The change could not be confirmed. Check your connection and try again.',
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() => obscured = state != AppLifecycleState.resumed);
    if (state == AppLifecycleState.paused) backgroundedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && backgroundedAt != null) {
      if (DateTime.now().difference(backgroundedAt!) >=
          const Duration(minutes: 30)) {
        unawaited(
          controller.loadRequest(widget.policy.origin.resolve('/customer')),
        );
      }
      backgroundedAt = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    push.dispose();
    unawaited(links?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (progress < 100 && !failed)
            LinearProgressIndicator(value: progress / 100),
          if (failed)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_outlined, size: 40),
                        const SizedBox(height: 18),
                        const Text('The portal could not be loaded.'),
                        const SizedBox(height: 8),
                        const Text(
                          'Check your connection and open the portal again.',
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => controller.loadRequest(
                            widget.policy.origin.resolve('/customer'),
                          ),
                          child: const Text('Open portal'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (obscured)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.white,
                child: Center(child: Text('LAS Top Technik')),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (pushEnabled)
            PopupMenuButton<bool>(
              tooltip: 'Notifications',
              enabled: !pushBusy,
              icon: pushBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_outlined),
              onSelected: (enable) => unawaited(_changeNotifications(enable)),
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Enable notifications')),
                PopupMenuItem(
                  value: false,
                  child: Text('Disable notifications'),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await controller.canGoBack()) await controller.goBack();
            },
          ),
          IconButton(
            tooltip: 'My portal',
            icon: const Icon(Icons.home_outlined),
            onPressed: () => controller.loadRequest(
              widget.policy.origin.resolve('/customer'),
            ),
          ),
        ],
      ),
    ),
  );
}
