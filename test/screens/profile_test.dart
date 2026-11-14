import 'package:floodlight/providers/account_providers.dart';
import 'package:floodlight/providers/session_providers.dart';
import 'package:floodlight/screens/auth/auth_screen.dart';
import 'package:floodlight/screens/onboarding/onboarding_screen.dart';
import 'package:floodlight/screens/profile/edit_profile_sheet.dart';
import 'package:floodlight/screens/profile/profile_tab.dart';
import 'package:floodlight/services/store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const tall = Size(390, 1500);

void main() {
  final seed = readSeed();
  setUp(quietMotion);

  testWidgets('shows the person, their record and what they follow', (t) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    expect(find.text('Olympicson'), findsWidgets);
    expect(find.text('hello@flutterzip.com'), findsOneWidget);
    expect(find.byKey(const Key('profile-record')), findsOneWidget);
    // Three teams and six picks are seeded.
    expect(find.text('3'), findsWidgets);
    expect(find.text('6'), findsOneWidget);
    final record = c.read(pickRecordProvider);
    expect(record.won + record.lost + record.open, 6);
    expect(record.won, 3);
    expect(record.lost, 1);
  });

  testWidgets('details can be edited, and bad ones are named', (t) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    await t.tap(find.byKey(ProfileKeys.edit));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(EditProfileKeys.name), '');
    await t.tap(find.byKey(EditProfileKeys.save));
    await t.pumpAndSettle();
    expect(c.read(profileProvider).value!.name, 'Olympicson');
    await t.enterText(find.byKey(EditProfileKeys.name), 'Ada Obi');
    await t.tap(find.byKey(EditProfileKeys.save));
    await t.pumpAndSettle();
    expect(c.read(profileProvider).value!.name, 'Ada Obi');
    expect(find.text('Ada Obi'), findsWidgets);
  });

  testWidgets('alert choices are kept, and thin the inbox out', (t) async {
    phone(t, size: tall);
    final (c, store) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    final before = c.read(alertsProvider).items.length;
    expect(before, greaterThan(0));
    await tapVisible(
      t,
      find.descendant(
        of: find.byKey(const Key('alerts-scores')),
        matching: find.byType(Switch),
      ),
    );
    expect(c.read(alertPrefsProvider).value!.scores, isFalse);
    expect(
      store.json<Map<String, dynamic>>(Store.alertPrefs)!['scores'],
      false,
    );
    expect(c.read(alertsProvider).items.length, lessThan(before));
  });

  testWidgets('appearance is one tap and is remembered', (t) async {
    phone(t, size: tall);
    final (c, store) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    await t.tap(find.byKey(const Key('appearance-Dark')));
    await t.pumpAndSettle();
    expect(c.read(themeModeProvider), ThemeMode.dark);
    expect(store.string(Store.themeMode), 'dark');
  });

  testWidgets('sign out hands over to sign in', (t) async {
    phone(t, size: tall);
    final (c, _) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    await t.tap(find.byKey(ProfileKeys.signOut));
    await t.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(c.read(sessionProvider), isNull);
  });

  testWidgets('reset asks first, then starts again from onboarding', (t) async {
    phone(t, size: tall);
    final (c, store) = await makeContainer(seed, signedIn: seed.profile);
    await pumpScreen(t, c, const ProfileTab());
    await c.read(followingProvider.notifier).follow('hbc');
    expect(store.strings(Store.following), contains('hbc'));
    await t.tap(find.byKey(ProfileKeys.reset));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('confirm-remove')));
    await t.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(store.strings(Store.following), isNull);
    expect(c.read(sessionProvider), isNull);
  });
}
