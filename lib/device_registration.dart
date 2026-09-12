import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'navigation_policy.dart';

enum DeviceResult { success, signInRequired, failed, timedOut, cancelled }

/// Acknowledges cookie-authenticated requests without exposing session cookies.
/// The JavaScript channel can only complete a pending request, never run actions.
class DeviceRegistration {
  DeviceRegistration({
    required this.policy,
    required this.currentUrl,
    required this.evaluate,
    this.timeout = const Duration(seconds: 12),
  });

  final NavigationPolicy policy;
  final Future<String?> Function() currentUrl;
  final Future<void> Function(String) evaluate;
  final Duration timeout;
  final Map<String, Completer<DeviceResult>> _pending = {};
  bool _disposed = false;
  int _pageEpoch = 0;

  Future<DeviceResult> request(String method, String token) async {
    if (_disposed) return DeviceResult.cancelled;
    final epoch = _pageEpoch;
    if (method != 'POST' && method != 'DELETE') return DeviceResult.failed;
    final uri = Uri.tryParse(await currentUrl() ?? '');
    if (_disposed || epoch != _pageEpoch) return DeviceResult.cancelled;
    if (uri == null || policy.classify(uri) != LinkAction.portal) {
      return DeviceResult.failed;
    }
    final random = Random.secure();
    final nonce = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final completer = Completer<DeviceResult>();
    _pending[nonce] = completer;
    final timer = Timer(timeout, () {
      _pending.remove(nonce)?.complete(DeviceResult.timedOut);
    });
    final origin = jsonEncode(policy.origin.origin);
    final encodedNonce = jsonEncode(nonce);
    final body = jsonEncode(jsonEncode({'token': token}));
    try {
      unawaited(
        evaluate('''(() => {
        if (location.origin !== $origin) return;
        const reply = (status) => LasPushRegistration.postMessage(JSON.stringify({
          nonce: $encodedNonce, origin: location.origin, status: status
        }));
        fetch('/customer/mobile/device', {
          method: ${jsonEncode(method)}, credentials: 'same-origin', redirect: 'error',
          headers: {'Content-Type': 'application/json', 'X-LAS-Mobile': '1'},
          body: $body
        }).then(r => reply(r.status)).catch(() => reply(0));
      })();''').catchError((Object _) {
          _pending.remove(nonce)?.complete(DeviceResult.failed);
        }),
      );
      return await completer.future;
    } catch (_) {
      return DeviceResult.failed;
    } finally {
      timer.cancel();
      _pending.remove(nonce);
    }
  }

  Future<void> receive(String message) async {
    if (_disposed || message.length > 1024) return;
    try {
      final payload = jsonDecode(message);
      if (payload is! Map<String, dynamic> ||
          payload['origin'] != policy.origin.origin ||
          payload['nonce'] is! String ||
          payload['status'] is! int) {
        return;
      }
      final uri = Uri.tryParse(await currentUrl() ?? '');
      if (_disposed ||
          uri == null ||
          policy.classify(uri) != LinkAction.portal) {
        return;
      }
      final completer = _pending.remove(payload['nonce']);
      completer?.complete(switch (payload['status']) {
        204 => DeviceResult.success,
        401 => DeviceResult.signInRequired,
        _ => DeviceResult.failed,
      });
    } catch (_) {
      // Malformed/unrelated messages never change registration state.
    }
  }

  void cancelPending() {
    _pageEpoch++;
    final requests = _pending.values.toList();
    _pending.clear();
    for (final request in requests) {
      request.complete(DeviceResult.cancelled);
    }
  }

  void dispose() {
    _disposed = true;
    cancelPending();
  }
}
