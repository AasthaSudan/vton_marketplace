import 'dart:typed_data';
import 'package:clothsy_shop/app.dart';
import 'package:clothsy_shop/features/settings/presentation/settings_screen.dart';
import 'package:clothsy_shop/features/tryon/presentation/providers/tryon_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the chosen appearance is remembered', () async {
    final first = ProviderContainer();
    await first.read(themeModeProvider.notifier).setThemeMode(ThemeMode.dark);
    first.dispose();

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(themeModeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(second.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('turning off photo consent asks first, then deletes photos', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repo = container.read(tryOnRepositoryProvider);

    await tester.runAsync(() async {
      await container.read(tryOnNotifierProvider.notifier).grantConsent();
      await repo.uploadUserPhoto(
        Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
      );
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Stop using your photos?'), findsOneWidget);

    await tester.tap(find.text('Turn off & delete'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(container.read(tryOnNotifierProvider).hasConsented, isFalse);
    final photos = await tester.runAsync(repo.getUserPhotos);
    expect(photos, isEmpty);
  });
}
