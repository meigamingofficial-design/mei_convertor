import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mei_convertor/app/app.dart';
import 'package:mei_convertor/core/services/storage/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('App smoke test — MaterialApp renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MeiConvertorApp()),
    );

    // Pump enough time to flush all flutter_animate timers (max animation ~600ms)
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
