import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Credentials never pass through portal JavaScript or URLs.
class DeviceLogin {
  DeviceLogin(this.origin, this.webView);
  final Uri origin;
  final WebViewController webView;
  static const channel = MethodChannel('com.lastoptechnik/device_login');

  Future<Map<String, dynamic>> _post(
    String route,
    Map<String, dynamic> body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.postUrl(
        origin.resolve('/customer/mobile/auth/$route'),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set('X-LAS-Native', '1');
      request.write(jsonEncode(body));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 401) throw const LoginFailure('password');
      if (response.statusCode != 200) throw const LoginFailure('unavailable');
      final data = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 15));
      return jsonDecode(data) as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handoff(Map<String, dynamic> data) async {
    final ticket = data['ticket'] as String;
    await webView.loadRequest(
      origin.resolve('/customer/mobile/auth/handoff'),
      method: LoadRequestMethod.post,
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'X-LAS-Native-Handoff': '1',
      },
      body: Uint8List.fromList(
        utf8.encode('ticket_value=${Uri.encodeQueryComponent(ticket)}'),
      ),
    );
  }

  Future<void> enroll(String username, String password) async {
    if (await channel.invokeMethod<bool>('available') != true) {
      throw const LoginFailure('passcode');
    }
    final data = await _post('enroll', {
      'username': username,
      'password': password,
    });
    final token = data['token'] as String;
    try {
      await channel.invokeMethod<void>('save', token);
    } catch (_) {
      try {
        await _post('revoke', {'token': token});
      } catch (_) {
        // Unstored credentials are unguessable and expire server-side.
      }
      rethrow;
    }
    await _handoff(data);
  }

  Future<void> login() async {
    final token = await channel.invokeMethod<String>('read');
    if (token == null) throw const LoginFailure('enroll');
    await _handoff(await _post('login', {'token': token}));
  }

  Future<bool> isEnrolled() async =>
      await channel.invokeMethod<bool>('enrolled') ?? false;

  Future<void> disable() async {
    final token = await channel.invokeMethod<String>('read');
    if (token != null) await _post('revoke', {'token': token});
    await forget();
    await webView.loadRequest(origin.resolve('/customer'));
  }

  Future<void> forget() => channel.invokeMethod<void>('delete');
}

class LoginFailure implements Exception {
  const LoginFailure(this.reason);
  final String reason;
}
