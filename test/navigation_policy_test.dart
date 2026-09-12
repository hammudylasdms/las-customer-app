import 'package:flutter_test/flutter_test.dart';
import 'package:las_customer/navigation_policy.dart';

void main() {
  final policy = NavigationPolicy(Uri.parse('https://dms.lastoptechnik.com'));
  test('existing signature links open externally but cannot be app links', () {
    final uri = Uri.parse(
      'https://dms.lastoptechnik.com/sign/abcdefghijklmnopqrstuv',
    );
    expect(policy.classify(uri), LinkAction.external);
    expect(policy.appDestination(uri), isNull);
    expect(
      policy.classify(Uri.parse('https://dms.lastoptechnik.com/sign/admin')),
      LinkAction.blocked,
    );
  });
  test('keeps customer navigation in the portal only', () {
    expect(
      policy.classify(
        Uri.parse('https://dms.lastoptechnik.com/customer/orders/12'),
      ),
      LinkAction.portal,
    );
    expect(
      policy.classify(
        Uri.parse('https://dms.lastoptechnik.com/api/v1/customers'),
      ),
      LinkAction.blocked,
    );
    expect(
      policy.classify(Uri.parse('https://dms.lastoptechnik.com/customer-evil')),
      LinkAction.blocked,
    );
  });
  test('does not trust lookalike hosts or embedded credentials', () {
    expect(
      policy.classify(
        Uri.parse('https://dms.lastoptechnik.com.evil.test/customer'),
      ),
      LinkAction.external,
    );
    expect(
      policy.classify(Uri.parse('https://user@dms.lastoptechnik.com/customer')),
      LinkAction.blocked,
    );
    expect(
      policy.classify(Uri.parse('javascript:alert(1)')),
      LinkAction.blocked,
    );
    expect(
      policy.classify(Uri.parse('http://dms.lastoptechnik.com/customer')),
      LinkAction.blocked,
    );
  });
  test('push and app links cannot trigger sensitive GET actions', () {
    expect(
      policy.appDestination(
        Uri.parse('https://dms.lastoptechnik.com/customer/orders/12'),
      ),
      isNotNull,
    );
    for (final path in [
      '/customer/tamara/invoices/12/checkout',
      '/customer/access/secret',
      '/customer/orders/12?next=evil',
      '/customer/orders/0',
      '/customer/orders/12#fragment',
    ]) {
      expect(
        policy.appDestination(Uri.parse('https://dms.lastoptechnik.com$path')),
        isNull,
      );
    }
  });
  test('rejects unsafe configured origins', () {
    for (final value in [
      'http://example.com',
      'https://u:p@example.com',
      'https://example.com/customer',
      'https://example.com?x=y',
    ]) {
      expect(() => NavigationPolicy(Uri.parse(value)), throwsArgumentError);
    }
  });
}
