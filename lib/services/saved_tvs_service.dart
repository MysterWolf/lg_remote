import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_tv.dart';

class SavedTvsService {
  static const _key = 'saved_tvs';

  Future<List<SavedTv>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<Map<String, dynamic>>().map(SavedTv.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _persist(List<SavedTv> tvs, SharedPreferences prefs) =>
      prefs.setString(_key, jsonEncode(tvs.map((t) => t.toJson()).toList()));

  Future<List<SavedTv>> add(List<SavedTv> current, SavedTv tv) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = [...current.where((t) => t.ip != tv.ip), tv];
    await _persist(updated, prefs);
    return updated;
  }

  Future<List<SavedTv>> remove(List<SavedTv> current, String ip) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = current.where((t) => t.ip != ip).toList();
    await _persist(updated, prefs);
    return updated;
  }

  Future<List<SavedTv>> rename(
      List<SavedTv> current, String ip, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final updated =
        current.map((t) => t.ip == ip ? t.copyWith(name: name) : t).toList();
    await _persist(updated, prefs);
    return updated;
  }

  Future<List<SavedTv>> updateLastSeen(
      List<SavedTv> current, String ip) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = current
        .map((t) => t.ip == ip ? t.copyWith(lastSeen: DateTime.now()) : t)
        .toList();
    await _persist(updated, prefs);
    return updated;
  }
}
