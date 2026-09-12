import 'dart:async';
import 'dart:convert';

import 'package:las_customer/device_registration.dart';
import 'package:las_customer/navigation_policy.dart';

/// Pure Dart checks also run without an iOS simulator or Firebase project.
Future<int> runDeviceRegistrationChecks() async {
  var checks = 0;
  void check(bool value, String message) {
    checks++;
    if (!value) throw StateError(message);
  }

  final policy = NavigationPolicy(Uri.parse('https://portal.test'));
  String nonce(String script) =>
      RegExp(r'nonce: "([a-f0-9]{48})"').firstMatch(script)!.group(1)!;
  String response(
    String id,
    int status, {
    String origin = 'https://portal.test',
  }) => jsonEncode({'nonce': id, 'origin': origin, 'status': status});

  for (final item in {
    204: DeviceResult.success,
    200: DeviceResult.failed,
    401: DeviceResult.signInRequired,
    403: DeviceResult.failed,
    500: DeviceResult.failed,
    0: DeviceResult.failed,
  }.entries) {
    final ready = Completer<String>();
    final bridge = DeviceRegistration(
      policy: policy,
      currentUrl: () async => 'https://portal.test/customer/dashboard',
      evaluate: (script) async => ready.complete(script),
    );
    final result = bridge.request('POST', 'test-token');
    final id = nonce(await ready.future);
    await bridge.receive(response(id, item.key));
    check(await result == item.value, 'Unexpected result for HTTP ${item.key}');
    bridge.dispose();
  }

  final ready = Completer<String>();
  final bridge = DeviceRegistration(
    policy: policy,
    currentUrl: () async => 'https://portal.test/customer',
    evaluate: (script) async => ready.complete(script),
    timeout: const Duration(milliseconds: 100),
  );
  final result = bridge.request('POST', 'test-token');
  final id = nonce(await ready.future);
  await bridge.receive('not json');
  await bridge.receive(response('wrong-nonce', 204));
  await bridge.receive(response(id, 204, origin: 'https://evil.test'));
  await bridge.receive(
    jsonEncode({'nonce': id, 'origin': 'https://portal.test', 'status': '204'}),
  );
  check(
    await result == DeviceResult.timedOut,
    'Untrusted messages must not acknowledge registration',
  );
  await bridge.receive(response(id, 204));
  bridge.dispose();

  final hangingEvaluation = Completer<void>();
  final bounded = DeviceRegistration(
    policy: policy,
    currentUrl: () async => 'https://portal.test/customer',
    evaluate: (_) => hangingEvaluation.future,
    timeout: const Duration(milliseconds: 20),
  );
  check(
    await bounded.request('POST', 'token') == DeviceResult.timedOut,
    'A hanging platform evaluation must be bounded',
  );
  hangingEvaluation.complete();
  bounded.dispose();

  var url = 'https://portal.test/customer';
  final pendingScripts = <String>[];
  final scriptsReady = Completer<void>();
  final parallel = DeviceRegistration(
    policy: policy,
    currentUrl: () async => url,
    evaluate: (script) async {
      pendingScripts.add(script);
      if (pendingScripts.length == 2) scriptsReady.complete();
    },
  );
  final first = parallel.request('POST', 'first');
  final second = parallel.request('DELETE', 'second');
  await scriptsReady.future;
  check(
    nonce(pendingScripts[0]) != nonce(pendingScripts[1]),
    'Requests need unique nonces',
  );
  await parallel.receive(response(nonce(pendingScripts[1]), 204));
  check(
    await second == DeviceResult.success,
    'Responses must match the correct request',
  );
  url = 'https://evil.test/customer';
  await parallel.receive(response(nonce(pendingScripts[0]), 204));
  parallel.cancelPending();
  check(
    await first == DeviceResult.cancelled,
    'Navigation must cancel pending registration',
  );
  check(
    await parallel.request('POST', 'token') == DeviceResult.failed,
    'No request on foreign origins',
  );
  parallel.dispose();
  check(
    await parallel.request('POST', 'token') == DeviceResult.cancelled,
    'Disposed bridge must reject requests',
  );

  var executions = 0;
  final guard = DeviceRegistration(
    policy: policy,
    currentUrl: () async => 'https://portal.test/customer',
    evaluate: (_) async {
      executions++;
      throw StateError('platform error');
    },
  );
  check(
    await guard.request('GET', 'token') == DeviceResult.failed,
    'Only defined mutation methods allowed',
  );
  check(executions == 0, 'Invalid methods must not execute JavaScript');
  check(
    await guard.request('POST', 'token') == DeviceResult.failed,
    'Platform errors must report failure',
  );
  guard.dispose();

  final pendingUrl = Completer<String?>();
  final navigationRace = DeviceRegistration(
    policy: policy,
    currentUrl: () => pendingUrl.future,
    evaluate: (_) async {
      throw StateError('Must not execute after navigation');
    },
  );
  final raced = navigationRace.request('POST', 'token');
  navigationRace.cancelPending();
  pendingUrl.complete('https://portal.test/customer');
  check(
    await raced == DeviceResult.cancelled,
    'Navigation during URL lookup must cancel',
  );
  navigationRace.dispose();
  return checks;
}
