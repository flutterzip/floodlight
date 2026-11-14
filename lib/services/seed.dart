import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/app_brand.dart';
import '../models/account.dart';

/// Everything bundled under assets/data/, decoded once.
///
/// Seed is read-only and edited by whoever uses the template; one JSON file
/// per entity, in the shape an API would send. What the user changes is
/// state, kept in [Store], never written back here. Only the Local and Demo
/// repositories read it.
class Seed {
  const Seed(this._raw);

  final Map<String, dynamic> _raw;

  static const files = ['competitions', 'teams', 'profile', 'demo'];

  List<Map<String, dynamic>> rows(String file) =>
      (_raw[file] as List).cast<Map<String, dynamic>>();

  Map<String, dynamic> object(String file) =>
      _raw[file] as Map<String, dynamic>;

  UserProfile get profile => UserProfile.fromJson(object('profile'));
  String get demoEmail => object('demo')['demoEmail'] as String;

  /// Typing this password shows the wrong-password state; any other
  /// well-formed sign-in succeeds, so a demo never dead-ends.
  String get wrongPassword => object('demo')['wrongPassword'] as String;

  /// The teams followed on a first launch.
  List<String> get following =>
      (object('demo')['following'] as List).cast<String>();

  /// Picks made before the first launch, placed relative to the round
  /// under way at the time. See `LocalAccountRepository`.
  List<Map<String, dynamic>> get picks =>
      (object('demo')['picks'] as List).cast<Map<String, dynamic>>();

  List<String> get recentSearches =>
      (object('demo')['recentSearches'] as List).cast<String>();

  /// Builds a seed from raw file contents keyed by file name (no extension).
  /// `{app}` becomes the product name.
  factory Seed.fromSources(Map<String, String> raw) => Seed({
    for (final f in files)
      f: jsonDecode(raw[f]!.replaceAll('{app}', AppBrand.name)),
  });

  static Future<Seed> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final raw = <String, String>{};
    for (final f in files) {
      raw[f] = await b.loadString('assets/data/$f.json');
    }
    return Seed.fromSources(raw);
  }
}
