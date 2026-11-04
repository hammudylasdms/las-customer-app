import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'navigation_policy.dart';
import 'push_service.dart';
import 'device_login.dart';
import 'login_screen.dart';
import 'brand_wordmark.dart';
import 'portal_presentation.dart';

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
      title: 'My LAS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff1967ce)),
        scaffoldBackgroundColor: Colors.white,
        navigationBarTheme: const NavigationBarThemeData(
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
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
  bool loginBusy = false;
  bool showLogin = true;
  bool pageReady = false;
  int pageGeneration = 0;
  Completer<void>? presentationReady;
  bool lightAppearance = false;
  bool faceIdEnrolled = false;
  int selectedTab = 0;
  Completer<bool>? loginNavigation;
  static const deviceLoginEnabled = bool.fromEnvironment('ENABLE_DEVICE_LOGIN');
  late final DeviceLogin deviceLogin;
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
    deviceLogin = DeviceLogin(widget.policy.origin, controller);
    push = PushService(controller, widget.policy);
    unawaited(_configure());
  }

  Future<void> _configure() async {
    try {
      if (deviceLoginEnabled && Platform.isIOS) {
        try {
          faceIdEnrolled = await deviceLogin.isEnrolled();
        } catch (_) {}
      }
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.setBackgroundColor(Colors.white);
      await controller.addJavaScriptChannel(
        'LasAppearance',
        onMessageReceived: (message) async {
          final url = await controller.currentUrl();
          final uri = url == null ? null : Uri.tryParse(url);
          if (uri == null || !widget.policy.sameOrigin(uri)) return;
          if (mounted && ['light', 'dark'].contains(message.message)) {
            setState(() => lightAppearance = message.message == 'light');
          }
        },
      );
      await controller.addJavaScriptChannel(
        'LasPageReady',
        onMessageReceived: (message) {
          final pending = presentationReady;
          if (message.message == pageGeneration.toString() &&
              pending != null &&
              !pending.isCompleted) {
            pending.complete();
          }
        },
      );
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
            if (deviceLoginEnabled &&
                Platform.isIOS &&
                request.isMainFrame &&
                widget.policy.sameOrigin(uri) &&
                uri.path == '/customer/logout') {
              await controller.loadRequest(
                widget.policy.origin.resolve('/customer/session/expire'),
                method: LoadRequestMethod.post,
              );
              return NavigationDecision.prevent;
            }
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
            pageGeneration++;
            final previous = presentationReady;
            if (previous != null && !previous.isCompleted) previous.complete();
            if (mounted) setState(() => pageReady = false);
            push.registration.cancelPending();
            if (mounted) setState(() => failed = false);
          },
          onPageFinished: (url) async {
            final generation = pageGeneration;
            if (await controller.currentUrl() != url ||
                generation != pageGeneration) {
              return;
            }
            final uri = Uri.tryParse(url);
            if (uri != null && widget.policy.sameOrigin(uri)) {
              final loginPage =
                  uri.path == '/customer' ||
                  uri.path == '/customer/' ||
                  uri.path == '/customer/login';
              if (mounted) setState(() => showLogin = loginPage);
              if (!loginPage) {
                try {
                  final ready = Completer<void>();
                  presentationReady = ready;
                  await controller.runJavaScript(
                    'void (async () => { try { await $portalPresentation } finally { requestAnimationFrame(() => requestAnimationFrame(() => LasPageReady.postMessage("$generation"))); } })();',
                  );
                  await ready.future.timeout(const Duration(seconds: 18));
                } catch (_) {
                  if (mounted && generation == pageGeneration) {
                    setState(() => failed = true);
                  }
                }
                if (generation != pageGeneration) return;
              }
              if (loginPage && deviceLoginEnabled && Platform.isIOS) {
                unawaited(
                  deviceLogin
                      .isEnrolled()
                      .then((value) {
                        if (mounted) setState(() => faceIdEnrolled = value);
                      })
                      .catchError((Object _) {}),
                );
              }
              final pending = loginNavigation;
              if (pending != null && !pending.isCompleted) {
                pending.complete(
                  !loginPage && uri.path == '/customer/dashboard',
                );
              }
            }
            if (mounted) setState(() => pageReady = true);
            if (pushEnabled) {
              unawaited(push.registerCurrentPage());
            }
          },
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => failed = true);
              final pending = loginNavigation;
              if (pending != null && !pending.isCompleted) {
                pending.complete(false);
              }
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

  Future<void> _submitLogin(
    String username,
    String password,
    bool useFaceId,
  ) async {
    if (loginNavigation != null) return;
    final pending = Completer<bool>();
    loginNavigation = pending;
    final completion = pending.future.timeout(
      const Duration(seconds: 35),
      onTimeout: () => false,
    );
    try {
      if (useFaceId && deviceLoginEnabled && Platform.isIOS) {
        if (username.isNotEmpty && password.isNotEmpty) {
          await deviceLogin.enroll(username, password);
        } else {
          await deviceLogin.login();
        }
      } else {
        await controller.loadRequest(
          widget.policy.origin.resolve('/customer/login'),
          method: LoadRequestMethod.post,
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: Uint8List.fromList(
            utf8.encode(
              'username=${Uri.encodeQueryComponent(username)}&password=${Uri.encodeQueryComponent(password)}',
            ),
          ),
        );
      }
      if (!await completion) throw StateError('Sign-in not completed');
    } finally {
      if (!pending.isCompleted) pending.complete(false);
      loginNavigation = null;
    }
  }

  Future<void> _deviceLogin(String action) async {
    if (loginBusy) return;
    setState(() => loginBusy = true);
    try {
      if (action == 'enable') {
        final username = TextEditingController();
        final password = TextEditingController();
        try {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Enable Face ID'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Confirm your portal login once. Your password is not saved. Face ID, Touch ID or your iPhone passcode will protect future sign-ins for up to 90 days.',
                    ),
                    TextField(
                      controller: username,
                      autocorrect: false,
                      textCapitalization: TextCapitalization.none,
                      decoration: const InputDecoration(labelText: 'Username'),
                    ),
                    TextField(
                      controller: password,
                      obscureText: true,
                      enableSuggestions: false,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Enable'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await deviceLogin.enroll(username.text.trim(), password.text);
            _notice('Device sign-in enabled.');
          }
        } finally {
          username.dispose();
          password.clear();
          password.dispose();
        }
      } else if (action == 'disable') {
        await deviceLogin.disable();
        _notice('Device sign-in disabled.');
      } else {
        await deviceLogin.login();
      }
    } on LoginFailure catch (error) {
      _notice(switch (error.reason) {
        'password' =>
          'Please sign in with your portal password and enable Face ID again.',
        'enroll' =>
          'Choose Enable Face ID and confirm your portal login first.',
        'passcode' => 'Set an iPhone passcode before enabling device sign-in.',
        _ =>
          'Device sign-in is not available. You can still use your portal password.',
      });
    } catch (_) {
      _notice(
        'Device sign-in was not completed. You can retry or use your portal password.',
      );
    } finally {
      if (mounted) setState(() => loginBusy = false);
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
    final pending = loginNavigation;
    if (pending != null && !pending.isCompleted) pending.complete(false);
    WidgetsBinding.instance.removeObserver(this);
    push.dispose();
    unawaited(links?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Scaffold(
        backgroundColor: lightAppearance
            ? const Color(0xfff3f5f7)
            : const Color(0xff17191b),
        appBar: AppBar(
          backgroundColor: lightAppearance
              ? Colors.white
              : const Color(0xff202224),
          foregroundColor: lightAppearance ? Colors.black87 : Colors.white,
          title: SizedBox(
            height: 42,
            child: Align(
              alignment: Alignment.topLeft,
              child: LasWordmark(
                size: 24,
                color: lightAppearance ? Colors.black87 : Colors.white,
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                if (await controller.canGoBack()) await controller.goBack();
              },
            ),
            if (deviceLoginEnabled && Platform.isIOS)
              PopupMenuButton<String>(
                tooltip: 'Face ID',
                enabled: !loginBusy,
                icon: const Icon(Icons.face_outlined),
                onSelected: (action) => unawaited(_deviceLogin(action)),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'enable', child: Text('Enable Face ID')),
                  PopupMenuItem(
                    value: 'disable',
                    child: Text('Disable Face ID'),
                  ),
                ],
              ),
            if (pushEnabled)
              IconButton(
                tooltip: 'Notifications',
                onPressed: pushBusy
                    ? null
                    : () => unawaited(_changeNotifications(true)),
                icon: const Icon(Icons.notifications_outlined),
              ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: () => controller.loadRequest(
                widget.policy.origin.resolve('/customer/session/expire'),
                method: LoadRequestMethod.post,
              ),
            ),
          ],
        ),
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
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              labelTextStyle: WidgetStatePropertyAll(
                TextStyle(
                  color: lightAppearance ? Colors.black87 : Colors.white70,
                  fontSize: 11,
                ),
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: lightAppearance
                ? Colors.white
                : const Color(0xff202224),
            indicatorColor: lightAppearance
                ? const Color(0xffdce6f0)
                : const Color(0xff34383c),
            selectedIndex: selectedTab,
            onDestinationSelected: (index) {
              setState(() {
                selectedTab = index;
                pageReady = false;
              });
              const paths = [
                '/customer/dashboard',
                '/customer/appointments',
                '/customer/dashboard?app_view=orders',
                '/customer/messages',
                '/customer/account',
              ];
              unawaited(
                controller.loadRequest(
                  widget.policy.origin.resolve(paths[index]),
                ),
              );
            },
            destinations: [
              NavigationDestination(
                icon: Icon(
                  Icons.dashboard_outlined,
                  color: lightAppearance ? Colors.black87 : Colors.white,
                ),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.calendar_month_outlined,
                  color: lightAppearance ? Colors.black87 : Colors.white,
                ),
                label: 'Appointments',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.receipt_long_outlined,
                  color: lightAppearance ? Colors.black87 : Colors.white,
                ),
                label: 'Orders',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: lightAppearance ? Colors.black87 : Colors.white,
                ),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.person_outline,
                  color: lightAppearance ? Colors.black87 : Colors.white,
                ),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
      if (!pageReady && !failed && !showLogin)
        Positioned.fill(
          child: ColoredBox(
            color: lightAppearance
                ? const Color(0xfff3f5f7)
                : const Color(0xff17191b),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
      if (showLogin)
        Positioned.fill(
          child: CustomerLoginScreen(
            onSubmit: _submitLogin,
            faceIdAvailable: deviceLoginEnabled && Platform.isIOS,
            faceIdEnrolled: faceIdEnrolled,
          ),
        ),
      if (showLogin && obscured)
        const Positioned.fill(child: ColoredBox(color: Colors.white)),
    ],
  );
}
