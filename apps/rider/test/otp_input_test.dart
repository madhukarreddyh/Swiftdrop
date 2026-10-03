import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swiftdrop_rider/widgets/otp_input.dart';

void main() {
  testWidgets('typing digits auto-advances through boxes',
      (tester) async {
    String? completed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OtpInput(
            onCompleted: (code) => completed = code,
          ),
        ),
      ),
    );

    // First box is autofocused.
    await tester.enterText(find.byKey(const ValueKey('otp-box-0')), '7');
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('otp-box-1')), '8');
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('otp-box-2')), '2');
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('otp-box-3')), '1');
    await tester.pump();

    expect(completed, '7821');
  });

  testWidgets('only digits are accepted', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OtpInput()),
      ),
    );

    await tester.enterText(
        find.byKey(const ValueKey('otp-box-0')), 'a');
    await tester.pump();
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('otp-box-0')),
    );
    expect(field.controller!.text, isEmpty);
  });

  testWidgets('clear() empties all boxes', (tester) async {
    final key = GlobalKey<OtpInputState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: OtpInput(key: key)),
      ),
    );

    await tester.enterText(find.byKey(const ValueKey('otp-box-0')), '1');
    await tester.pump();
    key.currentState!.clear();
    await tester.pump();

    expect(key.currentState!.code, isEmpty);
  });
}
