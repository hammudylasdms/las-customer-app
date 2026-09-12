import 'package:flutter_test/flutter_test.dart';
import 'device_registration_checks.dart';

void main() {
  test(
    'Device registration acknowledges only matching trusted responses',
    () async {
      expect(await runDeviceRegistrationChecks(), 17);
    },
  );
}
