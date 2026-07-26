import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:wheelchair_control/app/main_nav.dart';
import 'package:wheelchair_control/core/theme/app_theme.dart';
import 'package:wheelchair_control/core/widgets/battery_indicator.dart';
import 'package:wheelchair_control/providers/app_state.dart';

void main() {
  final state = AppState();

  Future<void> pumpAtSize(
    WidgetTester tester, {
    required Size size,
    required double textScale,
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.dark,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: const MainNav(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('control remains usable on a small phone', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(320, 568),
      textScale: 1,
    );
    expect(find.text('EMERGENCY STOP'), findsOneWidget);
    expect(find.byType(BatteryIndicator), findsOneWidget);
    expect(find.text('Unavailable'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('control supports enlarged caregiver text', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      textScale: 1.6,
    );

    expect(find.text('Control'), findsAtLeastNWidgets(1));
    expect(find.text('EMERGENCY STOP'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings exposes wheelchair removal', (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      textScale: 1,
    );

    await tester.tap(find.text('Settings').last);
    await tester.pump();

    expect(find.text('Remove wheelchair'), findsOneWidget);
    expect(find.text('Change wheelchair passkey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status exposes a clear wheelchair lock state and action',
      (tester) async {
    await pumpAtSize(
      tester,
      size: const Size(390, 844),
      textScale: 1,
    );

    await tester.tap(find.text('Status'));
    await tester.pump();

    expect(find.text('Wheelchair lock'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
    expect(find.text('Unlock wheelchair'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
