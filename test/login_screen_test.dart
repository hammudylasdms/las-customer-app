import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:las_customer/login_screen.dart';

void main() {
  testWidgets('password entry and submission use the supplied callback', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerLoginScreen(
          faceIdAvailable: true,
          onSubmit: (user, password, faceId) async {
            submitted = '$user:$password:$faceId';
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).at(0), 'customer');
    await tester.enterText(find.byType(TextField).at(1), 'example-password');
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(submitted, 'customer:example-password:false');
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and keyboard remain scrollable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 568),
            viewInsets: EdgeInsets.only(bottom: 260),
          ),
          child: CustomerLoginScreen(
            faceIdAvailable: true,
            onSubmit: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Face ID requires deliberate selection and permits saved-device sign in',
    (tester) async {
      bool? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomerLoginScreen(
            faceIdAvailable: true,
            onSubmit: (_, _, faceId) async {
              selected = faceId;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      expect(selected, true);
    },
  );
}
