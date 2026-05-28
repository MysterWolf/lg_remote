import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/saved_tv.dart';
import '../services/saved_tvs_service.dart';

class SavedTvsNotifier extends StateNotifier<List<SavedTv>> {
  final SavedTvsService _svc;

  SavedTvsNotifier(this._svc, {List<SavedTv> initial = const []})
      : super(initial);

  Future<void> add(SavedTv tv) async {
    state = await _svc.add(state, tv);
  }

  Future<void> remove(String ip) async {
    state = await _svc.remove(state, ip);
  }

  Future<void> rename(String ip, String name) async {
    state = await _svc.rename(state, ip, name);
  }

  Future<void> updateLastSeen(String ip) async {
    state = await _svc.updateLastSeen(state, ip);
  }

  void init(List<SavedTv> tvs) => state = tvs;

  bool isSaved(String ip) => state.any((t) => t.ip == ip);

  SavedTv? find(String ip) {
    for (final t in state) {
      if (t.ip == ip) return t;
    }
    return null;
  }
}

final savedTvsProvider =
    StateNotifierProvider<SavedTvsNotifier, List<SavedTv>>(
  (ref) => SavedTvsNotifier(SavedTvsService()),
);
