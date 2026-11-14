import 'package:daily_delivery_tracker/main.dart';
import 'package:daily_delivery_tracker/src/home_page.dart';
import 'package:daily_delivery_tracker/src/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('add milk, skip a day, copy the bill, and it is saved', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );

    final today = DateTime(2026, 11, 15);
    await tester.pumpWidget(DeliveryApp(home: HomePage(today: today)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Price per unit (₹)'),
      '56',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();

    // 1 to 15 November at 1 litre x 56.
    expect(find.text('₹840'), findsWidgets);

    await tester.tap(find.text('Milk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Did not come'));
    await tester.pumpAndSettle();
    expect(find.text('₹784'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('1 skipped'), findsOneWidget);

    await tester.tap(find.text('Copy bill as text'));
    await tester.pump();
    expect(clipboard, contains('Bill for November 2026 (up to 15 November)'));
    expect(clipboard, contains('Milk: 14 litre x Rs 56 = Rs 784'));

    final saved = await Store().load();
    expect(saved.single.overrides, {'2026-11-03': 0.0});
    expect(tester.takeException(), isNull);
  });

  testWidgets('cannot move past the current month', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      DeliveryApp(home: HomePage(today: DateTime(2026, 11, 15))),
    );
    await tester.pumpAndSettle();
    final next = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.chevron_right),
    );
    expect(next.onPressed, isNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
  });
}
