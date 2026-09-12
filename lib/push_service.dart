import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'device_registration.dart';
import 'navigation_policy.dart';

enum PushOutcome { enabled, disabled, permissionDenied, signInRequired, retry }

/// Optional; native Firebase/APNs configuration is required before activation.
class PushService {
  PushService(this.controller, this.policy)
    : registration = DeviceRegistration(
        policy: policy,
        currentUrl: controller.currentUrl,
        evaluate: controller.runJavaScript,
      );

  final WebViewController controller;
  final NavigationPolicy policy;
  final DeviceRegistration registration;
  StreamSubscription<String>? _tokens;
  StreamSubscription<RemoteMessage>? _opened;
  Future<void>? _initialisation;
  String? _token;
  bool _disabled = true;
  bool _disposed = false;
  bool _changing = false;

  Future<void> initialise() => _initialisation ??= _initialise();

  Future<void> _initialise() async {
    try {
      await Firebase.initializeApp();
      if (_disposed) return;
      final messaging = FirebaseMessaging.instance;
      _disabled = !messaging.isAutoInitEnabled;
      _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        unawaited(_open(message).catchError((Object _) {}));
      });
      final initial = await messaging.getInitialMessage();
      if (_disposed) return;
      if (initial != null) await _open(initial);
      if (_disposed) return;
      _tokens = messaging.onTokenRefresh.listen((token) {
        if (_disposed || _disabled || _changing) return;
        _token = token;
        unawaited(registerCurrentPage());
      }, onError: (Object _) {});
      final settings = await messaging.getNotificationSettings();
      if (!_disabled && _allowed(settings) && await _apnsReady()) {
        _token = await messaging.getToken();
        await registerCurrentPage();
      }
    } catch (_) {
      await _tokens?.cancel();
      await _opened?.cancel();
      _tokens = null;
      _opened = null;
      _initialisation = null;
      rethrow;
    }
  }

  bool _allowed(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  Future<bool> _apnsReady() async =>
      defaultTargetPlatform != TargetPlatform.iOS ||
      await FirebaseMessaging.instance.getAPNSToken() != null;

  Future<PushOutcome> enable() async {
    if (_changing || _disposed) return PushOutcome.retry;
    _changing = true;
    try {
      await initialise();
      final messaging = FirebaseMessaging.instance;
      if (!_allowed(await messaging.requestPermission())) {
        return PushOutcome.permissionDenied;
      }
      if (_disposed || !await _apnsReady()) return PushOutcome.retry;
      await messaging.setAutoInitEnabled(true);
      _disabled = false;
      _token = await messaging.getToken();
      final result = await registerCurrentPage();
      return switch (result) {
        DeviceResult.success => PushOutcome.enabled,
        DeviceResult.signInRequired => PushOutcome.signInRequired,
        _ => PushOutcome.retry,
      };
    } catch (_) {
      return PushOutcome.retry;
    } finally {
      _changing = false;
    }
  }

  Future<PushOutcome> disable() async {
    if (_changing || _disposed) return PushOutcome.retry;
    _changing = true;
    try {
      await initialise();
      _disabled = true;
      registration.cancelPending();
      final token = _token;
      _token = null;
      final messaging = FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(false);
      if (token != null) {
        // A logged-out user may not revoke via the portal; token invalidation
        // below still stops delivery and prevents automatic re-registration.
        await registration.request('DELETE', token);
      }
      await messaging.deleteToken();
      return PushOutcome.disabled;
    } catch (_) {
      // Never claim delivery stopped if provider-side invalidation failed.
      return PushOutcome.retry;
    } finally {
      _changing = false;
    }
  }

  Future<DeviceResult> registerCurrentPage() async {
    final token = _token;
    if (_disposed || _disabled || token == null) return DeviceResult.cancelled;
    try {
      return await registration.request('POST', token);
    } catch (_) {
      return DeviceResult.failed;
    }
  }

  Future<void> _open(RemoteMessage message) async {
    if (_disposed || message.data['destination'] != '/customer/dashboard') {
      return;
    }
    await controller.loadRequest(policy.origin.resolve('/customer/dashboard'));
  }

  void dispose() {
    _disposed = true;
    registration.dispose();
    unawaited(_tokens?.cancel());
    unawaited(_opened?.cancel());
  }
}
