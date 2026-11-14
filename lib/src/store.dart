import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'ledger.dart';

/// Keeps every item on this device only.
class Store {
  static const _key = 'items_v1';

  Future<List<Item>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      return [
        for (final j in jsonDecode(raw) as List)
          Item.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<Item> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final i in items) i.toJson()]),
      );
    } catch (_) {
      // Storage can be unavailable (private browsing). The app still works
      // for this visit.
    }
  }
}
